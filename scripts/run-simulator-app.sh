#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"

simulator_kind=""
simulator_id=""
app_path=""
bundle_identifier=""
expected_marker=""
log_path=""
timeout_seconds=30
leave_running=0

usage() {
  cat <<'EOF'
Usage: run-simulator-app.sh --kind iphone|ipad --app PATH --bundle-id ID \
  --marker TEXT --log PATH [--device-id UDID] [--timeout SECONDS] [--leave-running]

Boots, installs, and launches an app on one ARM64 Simulator, captures its
console, waits for a literal marker, and terminates the app by default.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --kind) simulator_kind="${2:-}"; shift 2 ;;
  --device-id) simulator_id="${2:-}"; shift 2 ;;
  --app) app_path="${2:-}"; shift 2 ;;
  --bundle-id) bundle_identifier="${2:-}"; shift 2 ;;
  --marker) expected_marker="${2:-}"; shift 2 ;;
  --log) log_path="${2:-}"; shift 2 ;;
  --timeout) timeout_seconds="${2:-}"; shift 2 ;;
  --leave-running) leave_running=1; shift ;;
  --help|-h) usage; exit 0 ;;
  *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "${simulator_kind}" in iphone|ipad) ;; *) usage >&2; exit 2 ;; esac
[[ -d "${app_path}" && -n "${bundle_identifier}" && \
   -n "${expected_marker}" && -n "${log_path}" ]] || { usage >&2; exit 2; }

mojo_ios_select_apple_toolchain
if [[ -z "${simulator_id}" ]]; then
  simulator_json="$(xcrun simctl list devices available --json)"
  simulator_id="$(
    SIMULATOR_KIND="${simulator_kind}" python3 -c '
import json, os, sys
payload = json.load(sys.stdin)
prefix = "iPhone" if os.environ["SIMULATOR_KIND"] == "iphone" else "iPad"
candidates = []
for runtime, devices in payload.get("devices", {}).items():
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith(prefix):
            candidates.append((runtime, device["name"], device["udid"]))
if not candidates:
    raise SystemExit(f"no available {prefix} Simulator")
print(sorted(candidates)[-1][2])
' <<<"${simulator_json}"
  )"
fi

mkdir -p "$(dirname "${log_path}")"
: >"${log_path}"
console_process_id=""
cleanup() {
  if [[ "${leave_running}" = 0 ]]; then
    xcrun simctl terminate "${simulator_id}" "${bundle_identifier}" \
      >/dev/null 2>&1 || true
  fi
  if [[ -n "${console_process_id}" ]] && \
    kill -0 "${console_process_id}" 2>/dev/null; then
    if [[ "${leave_running}" = 1 ]]; then
      kill -KILL "${console_process_id}" 2>/dev/null || true
    else
      kill -INT "${console_process_id}" 2>/dev/null || true
    fi
    wait "${console_process_id}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

xcrun simctl bootstatus "${simulator_id}" -b
xcrun simctl install "${simulator_id}" "${app_path}"
xcrun simctl launch --console-pty --terminate-running-process \
  "${simulator_id}" "${bundle_identifier}" >"${log_path}" 2>&1 &
console_process_id=$!

"${project_root}/scripts/wait-for-marker.sh" \
  --log "${log_path}" \
  --literal "${expected_marker}" \
  --timeout "${timeout_seconds}" \
  --process "${console_process_id}"
cat "${log_path}"
printf 'SIMULATOR_APP_PASS kind=%s device=%s bundle=%s cleanup=%s\n' \
  "${simulator_kind}" "${simulator_id}" "${bundle_identifier}" \
  "$([[ "${leave_running}" = 0 ]] && echo terminated || echo left-running)"
