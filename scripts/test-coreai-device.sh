#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_bundle="${project_root}/build/CoreAIDeviceSmoke/Debug-iphoneos/MojoIOSCoreAIDeviceSmoke.app"
bundle_identifier="com.ianhorn.mojoios.coreai.devicesmoke"
expected_marker="MOJO_IOS_COREAI_DEVICE_SMOKE_PASS source=standard-mojo graph=matmul-matmul calls=sequential-concurrent concurrent_rounds=10 fallback=none ane=preferred"
device_result_path="${project_root}/build/CoreAIDeviceSmoke/CoreAIDeviceSmokeResult.txt"

: "${MOJO_IOS_COREAI_DEVELOPER_DIR:?Set MOJO_IOS_COREAI_DEVELOPER_DIR to the Xcode 27 Contents/Developer directory}"
: "${MOJO_IOS_CORE_DEVICE_ID:?Set MOJO_IOS_CORE_DEVICE_ID to the physical CoreDevice identifier}"

export DEVELOPER_DIR="${MOJO_IOS_COREAI_DEVELOPER_DIR}"
device_details="$(
  xcrun devicectl device info details \
    --device "${MOJO_IOS_CORE_DEVICE_ID}" \
    --timeout 20
)"
device_os_version="$(
  sed -n 's/^    • OS Version: //p' <<<"${device_details}"
)"
device_os_major_version="${device_os_version%%.*}"
if [[ ! "${device_os_major_version}" =~ ^[0-9]+$ ]] || \
  (( device_os_major_version < 27 )); then
  echo "Core AI device execution requires iPadOS/iOS 27; device reports ${device_os_version:-unknown}" >&2
  exit 2
fi

: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set MOJO_IOS_DEVELOPMENT_TEAM to the Apple development team identifier}"
"${project_root}/scripts/build-coreai-device-smoke.sh"

xcrun devicectl device install app \
  --device "${MOJO_IOS_CORE_DEVICE_ID}" \
  "${app_bundle}"

execution_nonce="$(uuidgen)"
launch_output="$(
  xcrun devicectl device process launch \
    --device "${MOJO_IOS_CORE_DEVICE_ID}" \
    --timeout 600 \
    --console \
    --terminate-existing \
    --environment-variables \
      "{\"MOJO_IOS_COREAI_EXECUTION_NONCE\":\"${execution_nonce}\"}" \
    "${bundle_identifier}"
)"
printf '%s\n' "${launch_output}"
xcrun devicectl device copy from \
  --device "${MOJO_IOS_CORE_DEVICE_ID}" \
  --domain-type appDataContainer \
  --domain-identifier "${bundle_identifier}" \
  --source Documents/CoreAIDeviceSmokeResult.txt \
  --destination "${device_result_path}"

device_result="$(<"${device_result_path}")"
printf '%s\n' "${device_result}"
rg -Fxq \
  "${expected_marker} execution_nonce=${execution_nonce}" \
  <<<"${device_result}"
