#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"
build_root="${project_root}/build/cpu-conformance/apps/device"
mojo_ios_select_apple_toolchain
manifest_path="${project_root}/tests/cpu-conformance/manifest.tsv"
family_count="$(( $(wc -l <"${manifest_path}") - 1 ))"
test "${family_count}" -gt 0

: "${MOJO_IOS_CORE_DEVICE_ID:?Set the physical CoreDevice identifier}"
: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set the Apple development team identifier}"

for optimization_level in 0 3; do
  variant_root="${build_root}-o${optimization_level}"
  bundle_identifier="com.ianhorn.mojoios.cpuconformance.o${optimization_level}"
  app_path="${variant_root}/Debug-iphoneos/MojoIOSCPUConformance.app"
  console_log="${variant_root}/device-console.log"
  expected_marker="CPU_CONFORMANCE_APP_PASS optimization=${optimization_level} families=${family_count} foreign_threads=yes"
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
  "${project_root}/scripts/run-device-app.sh" \
    --device-id "${MOJO_IOS_CORE_DEVICE_ID}" \
    --app "${app_path}" \
    --bundle-id "${bundle_identifier}" \
    --marker "${expected_marker}" \
    --log "${console_log}"
done

echo "CPU_CONFORMANCE_DEVICE_PASS families=${family_count} optimizations=0,3 foreign_threads=yes"
