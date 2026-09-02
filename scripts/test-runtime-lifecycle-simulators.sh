#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build/runtime-lifecycle/apps"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
export DEVELOPER_DIR="${developer_directory}"
command -v jq >/dev/null

available_simulators_json="$(xcrun simctl list devices available --json)"
resolve_simulator_id() {
  local device_name_prefix="$1"
  jq -er --arg prefix "${device_name_prefix}" \
    '[.devices | to_entries[] | .value[] | select(.isAvailable == true) |
      select(.name | startswith($prefix)) | .udid] | last' \
    <<<"${available_simulators_json}"
}

iphone_simulator_id="${IPHONE_SIMULATOR_ID:-$(resolve_simulator_id iPhone)}"
ipad_simulator_id="${IPAD_SIMULATOR_ID:-$(resolve_simulator_id iPad)}"

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

run_variant() {
  local optimization_level="$1"
  local link_order="$2"
  local simulator_id="$3"
  local simulator_kind="$4"
  local libraries_root="${project_root}/build/runtime-lifecycle/iphonesimulator-o${optimization_level}"
  local variant_root="${build_root}/${simulator_kind}-${link_order}-o${optimization_level}"
  local bundle_identifier="com.ianhorn.mojoios.runtimelifecycle.${link_order}.o${optimization_level}"
  local app_path="${variant_root}/Debug-iphonesimulator/MojoIOSRuntimeLifecycle.app"
  local console_log="${variant_root}/simulator-console.log"
  local ready_marker="RUNTIME_LIFECYCLE_APP_READY optimization=${optimization_level} link_order=${link_order}"
  local pass_marker="RUNTIME_LIFECYCLE_APP_PASS optimization=${optimization_level} link_order=${link_order}"
  local background_marker="RUNTIME_LIFECYCLE_BACKGROUND optimization=${optimization_level} link_order=${link_order}"
  local foreground_marker="RUNTIME_LIFECYCLE_FOREGROUND_PASS optimization=${optimization_level} link_order=${link_order}"

  cmake \
    -S "${project_root}/RuntimeLifecycle" \
    -B "${variant_root}" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DMOJO_IOS_LIFECYCLE_LIBRARY_A="${libraries_root}/libLifecycleA.a" \
    -DMOJO_IOS_LIFECYCLE_LIBRARY_B="${libraries_root}/libLifecycleB.a" \
    -DMOJO_IOS_LIFECYCLE_HARNESS="${libraries_root}/libLifecycleHarness.a" \
    -DMOJO_IOS_LIFECYCLE_OPTIMIZATION="${optimization_level}" \
    -DMOJO_IOS_LIFECYCLE_LINK_ORDER="${link_order}"
  cmake --build "${variant_root}" --config Debug \
    --target MojoIOSRuntimeLifecycle -- -quiet CODE_SIGNING_ALLOWED=NO
  test -d "${app_path}"

  xcrun simctl bootstatus "${simulator_id}" -b
  xcrun simctl install "${simulator_id}" "${app_path}"
  : >"${console_log}"
  xcrun simctl launch --console --terminate-running-process \
    "${simulator_id}" "${bundle_identifier}" >"${console_log}" 2>&1 &
  local console_process_id=$!
  if ! wait_for_marker "${ready_marker}" "${console_log}"; then
    cat "${console_log}"
    echo "runtime lifecycle Simulator app did not become ready" >&2
    exit 1
  fi
  local app_process_id
  app_process_id="$(sed -n 's/.*RUNTIME_LIFECYCLE_APP_READY.* pid=\([0-9][0-9]*\).*/\1/p' "${console_log}" | tail -n 1)"
  test -n "${app_process_id}"

  /bin/kill -STOP "${app_process_id}"
  sleep 4
  if grep -Fq "${pass_marker}" "${console_log}"; then
    echo "runtime lifecycle completion advanced while the Simulator process was suspended" >&2
    exit 1
  fi
  /bin/kill -CONT "${app_process_id}"
  wait_for_marker "${pass_marker}" "${console_log}"

  xcrun simctl openurl "${simulator_id}" https://example.invalid/
  wait_for_marker "${background_marker}" "${console_log}"
  xcrun simctl launch "${simulator_id}" "${bundle_identifier}" >/dev/null
  wait_for_marker "${foreground_marker}" "${console_log}"

  xcrun simctl terminate "${simulator_id}" "${bundle_identifier}"
  wait "${console_process_id}" 2>/dev/null || true
  cat "${console_log}"
}

for optimization_level in 0 3; do
  for link_order in ab ba; do
    run_variant "${optimization_level}" "${link_order}" \
      "${iphone_simulator_id}" iphone
    run_variant "${optimization_level}" "${link_order}" \
      "${ipad_simulator_id}" ipad
  done
done

echo "RUNTIME_LIFECYCLE_SIMULATOR_PASS devices=iphone,ipad link_orders=ab,ba optimizations=0,3 suspend_resume=yes foreground_background=yes"
