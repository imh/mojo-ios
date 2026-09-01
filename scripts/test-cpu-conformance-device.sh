#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build/cpu-conformance/apps/device"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
export DEVELOPER_DIR="${developer_directory}"

: "${MOJO_IOS_CORE_DEVICE_ID:?Set the physical CoreDevice identifier}"
: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set the Apple development team identifier}"

for optimization_level in 0 3; do
  variant_root="${build_root}-o${optimization_level}"
  bundle_identifier="com.ianhorn.mojoios.cpuconformance.o${optimization_level}"
  app_path="${variant_root}/Debug-iphoneos/MojoIOSCPUConformance.app"
  console_log="${variant_root}/device-console.log"
  expected_marker="CPU_CONFORMANCE_APP_PASS optimization=${optimization_level} families=6 foreign_threads=yes"
  cmake \
    -S "${project_root}/CPUConformance" \
    -B "${variant_root}" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DMOJO_IOS_CONFORMANCE_LIBRARY="${project_root}/build/cpu-conformance/iphoneos-o${optimization_level}/libCPUConformance.a" \
    -DMOJO_IOS_CONFORMANCE_OPTIMIZATION="${optimization_level}" \
    -DMOJO_IOS_DEVELOPMENT_TEAM="${MOJO_IOS_DEVELOPMENT_TEAM}"
  cmake --build "${variant_root}" --config Debug \
    --target MojoIOSCPUConformance -- -allowProvisioningUpdates
  test -d "${app_path}"
  xcrun devicectl device install app \
    --device "${MOJO_IOS_CORE_DEVICE_ID}" "${app_path}"
  : >"${console_log}"
  xcrun devicectl device process launch \
    --device "${MOJO_IOS_CORE_DEVICE_ID}" --console --terminate-existing \
    "${bundle_identifier}" >"${console_log}" 2>&1 &
  console_process_id=$!

  marker_observed=0
  for _ in {1..30}; do
    if grep -Fq "${expected_marker}" "${console_log}"; then
      marker_observed=1
      break
    fi
    if ! kill -0 "${console_process_id}" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if kill -0 "${console_process_id}" 2>/dev/null; then
    kill -INT "${console_process_id}" 2>/dev/null || true
  fi
  wait "${console_process_id}" 2>/dev/null || true
  cat "${console_log}"
  if [[ "${marker_observed}" != 1 ]]; then
    echo "physical CPU conformance app did not emit its completion marker" >&2
    exit 1
  fi
done

echo "CPU_CONFORMANCE_DEVICE_PASS families=6 optimizations=0,3 foreign_threads=yes"
