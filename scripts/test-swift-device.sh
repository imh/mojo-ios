#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device_smoke_app="${project_root}/build/DeviceSmoke/Debug-iphoneos/MojoIOSDeviceSmoke.app"
device_smoke_bundle_identifier="com.ianhorn.mojoios.devicesmoke"
enable_metal_smoke="${MOJO_IOS_ENABLE_METAL_SMOKE:-OFF}"
expected_marker="MOJO_IOS_DEVICE_SMOKE_PASS result=42 list_sum=4950 iterations=1000 globals=recreated process=integrated parallel_api=passed foreign_threads=passed async=suspend-resume-errors"

case "${enable_metal_smoke}" in
  ON) expected_marker="${expected_marker} metal=useful-mvp" ;;
  OFF) ;;
  *)
    echo "MOJO_IOS_ENABLE_METAL_SMOKE must be ON or OFF" >&2
    exit 2
    ;;
esac

: "${MOJO_IOS_CORE_DEVICE_ID:?Set MOJO_IOS_CORE_DEVICE_ID to the CoreDevice identifier from xcrun devicectl list devices}"
: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set MOJO_IOS_DEVELOPMENT_TEAM to the Apple development team identifier}"

"${project_root}/scripts/build-device-smoke.sh"

xcrun devicectl device install app \
  --device "${MOJO_IOS_CORE_DEVICE_ID}" \
  "${device_smoke_app}"

launch_output="$(
  xcrun devicectl device process launch \
    --device "${MOJO_IOS_CORE_DEVICE_ID}" \
    --console \
    --terminate-existing \
    "${device_smoke_bundle_identifier}"
)"

printf '%s\n' "${launch_output}"
grep -Fq "${expected_marker}" <<<"${launch_output}"
