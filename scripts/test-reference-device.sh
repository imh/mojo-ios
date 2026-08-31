#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_app="${project_root}/build/ReferenceApp/MojoIOSReferenceApp.xcarchive/Products/Applications/MojoIOSReferenceApp.app"
console_log="${project_root}/build/ReferenceApp/device-console.log"
bundle_identifier="${MOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER:-com.ianhorn.mojoios.reference}"
expected_marker="MOJO_IOS_REFERENCE_APP_PASS cpu=yes async=yes metal=yes"
skip_build="${MOJO_IOS_REFERENCE_SKIP_BUILD:-0}"

: "${MOJO_IOS_CORE_DEVICE_ID:?Set MOJO_IOS_CORE_DEVICE_ID to the physical CoreDevice identifier}"

case "${skip_build}" in
  0|1) ;;
  *)
    echo "MOJO_IOS_REFERENCE_SKIP_BUILD must be 0 or 1" >&2
    exit 2
    ;;
esac

if [[ "${skip_build}" = 0 ]]; then
  "${project_root}/scripts/build-reference-archive.sh"
fi
test -d "${archive_app}"

xcrun devicectl device install app \
  --device "${MOJO_IOS_CORE_DEVICE_ID}" \
  "${archive_app}"

: >"${console_log}"
xcrun devicectl device process launch \
  --device "${MOJO_IOS_CORE_DEVICE_ID}" \
  --console \
  --terminate-existing \
  "${bundle_identifier}" >"${console_log}" 2>&1 &
console_process_id=$!

stop_console() {
  if kill -0 "${console_process_id}" 2>/dev/null; then
    kill -INT "${console_process_id}" 2>/dev/null || true
    wait "${console_process_id}" 2>/dev/null || true
  fi
}
trap stop_console EXIT

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

cat "${console_log}"
if [[ "${marker_observed}" != 1 ]]; then
  echo "physical reference app did not emit its completion marker" >&2
  exit 1
fi

echo "REFERENCE_DEVICE_PASS device=${MOJO_IOS_CORE_DEVICE_ID} cpu=yes async=yes metal=yes"
