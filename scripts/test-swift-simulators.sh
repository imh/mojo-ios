#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data_root="${project_root}/build/DerivedData"

test -d "${project_root}/build/MojoIOSCore.xcframework"
command -v jq >/dev/null

available_simulators_json="$(xcrun simctl list devices available --json)"

resolve_simulator_id() {
  local device_name_prefix="$1"

  jq -er \
    --arg device_name_prefix "${device_name_prefix}" \
    '[
      .devices
      | to_entries[]
      | .value[]
      | select(.isAvailable == true)
      | select(.name | startswith($device_name_prefix))
      | .udid
    ]
    | last' \
    <<<"${available_simulators_json}"
}

iphone_simulator_id="${IPHONE_SIMULATOR_ID:-$(resolve_simulator_id iPhone)}"
ipad_simulator_id="${IPAD_SIMULATOR_ID:-$(resolve_simulator_id iPad)}"

test -n "${iphone_simulator_id}"
test -n "${ipad_simulator_id}"
test "${iphone_simulator_id}" != "${ipad_simulator_id}"

cd "${project_root}"

xcodebuild \
  -scheme MojoIOS \
  -destination "platform=iOS Simulator,id=${iphone_simulator_id}" \
  -derivedDataPath "${derived_data_root}/iphone-simulator-tests" \
  CODE_SIGNING_ALLOWED=NO \
  test

xcodebuild \
  -scheme MojoIOS \
  -destination "platform=iOS Simulator,id=${ipad_simulator_id}" \
  -derivedDataPath "${derived_data_root}/ipad-simulator-tests" \
  CODE_SIGNING_ALLOWED=NO \
  test
