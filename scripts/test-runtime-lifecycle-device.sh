#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build/runtime-lifecycle/apps/device"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
export DEVELOPER_DIR="${developer_directory}"

: "${MOJO_IOS_CORE_DEVICE_ID:?Set the physical CoreDevice identifier}"
: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set the Apple development team identifier}"

wait_for_marker() {
  local marker="$1"
  local log_path="$2"
  for _ in {1..45}; do
    if grep -Fq "${marker}" "${log_path}"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

for optimization_level in 0 3; do
  for link_order in ab ba; do
    libraries_root="${project_root}/build/runtime-lifecycle/iphoneos-o${optimization_level}"
    variant_root="${build_root}-${link_order}-o${optimization_level}"
    bundle_identifier="com.ianhorn.mojoios.runtimelifecycle.${link_order}.o${optimization_level}"
    app_path="${variant_root}/Debug-iphoneos/MojoIOSRuntimeLifecycle.app"
    console_log="${variant_root}/device-console.log"
    ready_marker="RUNTIME_LIFECYCLE_APP_READY optimization=${optimization_level} link_order=${link_order}"
    pass_marker="RUNTIME_LIFECYCLE_APP_PASS optimization=${optimization_level} link_order=${link_order}"
    background_marker="RUNTIME_LIFECYCLE_BACKGROUND optimization=${optimization_level} link_order=${link_order}"
    foreground_marker="RUNTIME_LIFECYCLE_FOREGROUND_PASS optimization=${optimization_level} link_order=${link_order}"

    cmake \
      -S "${project_root}/RuntimeLifecycle" \
      -B "${variant_root}" \
      -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_SYSROOT=iphoneos \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DMOJO_IOS_LIFECYCLE_LIBRARY_A="${libraries_root}/libLifecycleA.a" \
      -DMOJO_IOS_LIFECYCLE_LIBRARY_B="${libraries_root}/libLifecycleB.a" \
      -DMOJO_IOS_LIFECYCLE_HARNESS="${libraries_root}/libLifecycleHarness.a" \
      -DMOJO_IOS_LIFECYCLE_OPTIMIZATION="${optimization_level}" \
      -DMOJO_IOS_LIFECYCLE_LINK_ORDER="${link_order}" \
      -DMOJO_IOS_DEVELOPMENT_TEAM="${MOJO_IOS_DEVELOPMENT_TEAM}"
    cmake --build "${variant_root}" --config Debug \
      --target MojoIOSRuntimeLifecycle -- -quiet -allowProvisioningUpdates
    test -d "${app_path}"

    xcrun devicectl device install app \
      --device "${MOJO_IOS_CORE_DEVICE_ID}" "${app_path}"
    : >"${console_log}"
    xcrun devicectl device process launch \
      --device "${MOJO_IOS_CORE_DEVICE_ID}" --console --terminate-existing \
      "${bundle_identifier}" >"${console_log}" 2>&1 &
    console_process_id=$!
    if ! wait_for_marker "${ready_marker}" "${console_log}"; then
      cat "${console_log}"
      echo "physical runtime lifecycle app did not become ready" >&2
      exit 1
    fi
    app_process_id="$(sed -n 's/.*RUNTIME_LIFECYCLE_APP_READY.* pid=\([0-9][0-9]*\).*/\1/p' "${console_log}" | tail -n 1)"
    test -n "${app_process_id}"

    xcrun devicectl device process suspend \
      --device "${MOJO_IOS_CORE_DEVICE_ID}" --pid "${app_process_id}"
    sleep 4
    if grep -Fq "${pass_marker}" "${console_log}"; then
      echo "runtime lifecycle completion advanced while the iPad process was suspended" >&2
      exit 1
    fi
    xcrun devicectl device process resume \
      --device "${MOJO_IOS_CORE_DEVICE_ID}" --pid "${app_process_id}"
    wait_for_marker "${pass_marker}" "${console_log}"

    xcrun devicectl device process openURL \
      --device "${MOJO_IOS_CORE_DEVICE_ID}" https://example.invalid/
    wait_for_marker "${background_marker}" "${console_log}"
    xcrun devicectl device process launch \
      --device "${MOJO_IOS_CORE_DEVICE_ID}" --activate \
      "${bundle_identifier}" >/dev/null
    wait_for_marker "${foreground_marker}" "${console_log}"

    xcrun devicectl device process terminate \
      --device "${MOJO_IOS_CORE_DEVICE_ID}" --pid "${app_process_id}" \
      >/dev/null
    wait "${console_process_id}" 2>/dev/null || true
    cat "${console_log}"
  done
done

echo "RUNTIME_LIFECYCLE_DEVICE_PASS device=ipad link_orders=ab,ba optimizations=0,3 suspend_resume=yes foreground_background=yes"
