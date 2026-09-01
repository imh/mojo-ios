#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build/cpu-conformance/apps"
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

run_variant() {
  local optimization_level="$1"
  local simulator_id="$2"
  local simulator_kind="$3"
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
  xcrun simctl bootstatus "${simulator_id}" -b
  xcrun simctl install "${simulator_id}" "${app_path}"
  local console_log="${variant_root}/simulator-console.log"
  local expected_marker="CPU_CONFORMANCE_APP_PASS optimization=${optimization_level} families=6 foreign_threads=yes"
  : >"${console_log}"
  xcrun simctl launch --console-pty --terminate-running-process \
    "${simulator_id}" "${bundle_identifier}" >"${console_log}" 2>&1 &
  local console_process_id=$!
  local marker_observed=0
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
  xcrun simctl terminate "${simulator_id}" "${bundle_identifier}" \
    >/dev/null 2>&1 || true
  cat "${console_log}"
  if [[ "${marker_observed}" != 1 ]]; then
    echo "${simulator_kind} CPU conformance app did not emit its completion marker" >&2
    exit 1
  fi
}

for optimization_level in 0 3; do
  run_variant "${optimization_level}" "${iphone_simulator_id}" iphone
  run_variant "${optimization_level}" "${ipad_simulator_id}" ipad
done

echo "CPU_CONFORMANCE_SIMULATOR_PASS families=6 devices=iphone,ipad optimizations=0,3"
