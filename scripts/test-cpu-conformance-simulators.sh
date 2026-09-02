#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"
build_root="${project_root}/build/cpu-conformance/apps"
mojo_ios_select_apple_toolchain
manifest_path="${project_root}/tests/cpu-conformance/manifest.tsv"
family_count="$(( $(wc -l <"${manifest_path}") - 1 ))"
test "${family_count}" -gt 0

run_variant() {
  local optimization_level="$1"
  local simulator_kind="$2"
  local variant_root="${build_root}/${simulator_kind}-o${optimization_level}"
  local bundle_identifier="com.ianhorn.mojoios.cpuconformance.o${optimization_level}"
  local app_path="${variant_root}/Debug-iphonesimulator/MojoIOSCPUConformance.app"

  cmake \
    -S "${project_root}/CPUConformance" \
    -B "${variant_root}" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DMOJO_IOS_CONFORMANCE_LIBRARY="${project_root}/build/cpu-conformance/iphonesimulator-o${optimization_level}/libCPUConformance.a" \
    -DMOJO_IOS_CONFORMANCE_OPTIMIZATION="${optimization_level}"
  cmake --build "${variant_root}" --config Debug \
    --target MojoIOSCPUConformance -- CODE_SIGNING_ALLOWED=NO
  test -d "${app_path}"
  local console_log="${variant_root}/simulator-console.log"
  local expected_marker="CPU_CONFORMANCE_APP_PASS optimization=${optimization_level} families=${family_count} foreign_threads=yes"
  local runner_arguments=(
    --kind "${simulator_kind}"
    --app "${app_path}"
    --bundle-id "${bundle_identifier}"
    --marker "${expected_marker}"
    --log "${console_log}"
  )
  if [[ "${simulator_kind}" = iphone ]] && [[ -n "${IPHONE_SIMULATOR_ID:-}" ]]; then
    runner_arguments+=(--device-id "${IPHONE_SIMULATOR_ID}")
  elif [[ "${simulator_kind}" = ipad ]] && [[ -n "${IPAD_SIMULATOR_ID:-}" ]]; then
    runner_arguments+=(--device-id "${IPAD_SIMULATOR_ID}")
  fi
  "${project_root}/scripts/run-simulator-app.sh" "${runner_arguments[@]}"
}

for optimization_level in 0 3; do
  run_variant "${optimization_level}" iphone
  run_variant "${optimization_level}" ipad
done

echo "CPU_CONFORMANCE_SIMULATOR_PASS families=${family_count} devices=iphone,ipad optimizations=0,3"
