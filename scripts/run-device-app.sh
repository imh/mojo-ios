#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"

device_id="${MOJO_IOS_CORE_DEVICE_ID:-}"
app_path=""
bundle_identifier=""
expected_marker=""
log_path=""
timeout_seconds=45
leave_running=0
environment_json=""

usage() {
  cat <<'EOF'
Usage: run-device-app.sh --app PATH --bundle-id ID --marker TEXT --log PATH \
  [--device-id ID] [--timeout SECONDS] [--environment-json JSON] [--leave-running]

Preflights, installs, and launches a signed app on one physical device, waits
for a literal console marker, and terminates the launched app by default.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --device-id) device_id="${2:-}"; shift 2 ;;
  --app) app_path="${2:-}"; shift 2 ;;
  --bundle-id) bundle_identifier="${2:-}"; shift 2 ;;
  --marker) expected_marker="${2:-}"; shift 2 ;;
  --log) log_path="${2:-}"; shift 2 ;;
  --timeout) timeout_seconds="${2:-}"; shift 2 ;;
  --environment-json) environment_json="${2:-}"; shift 2 ;;
  --leave-running) leave_running=1; shift ;;
  --help|-h) usage; exit 0 ;;
  *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "${device_id}" && -d "${app_path}" && -n "${bundle_identifier}" && \
   -n "${expected_marker}" && -n "${log_path}" ]] || { usage >&2; exit 2; }
[[ -z "${environment_json}" ]] || \
  python3 -c 'import json,sys; value=json.loads(sys.argv[1]); assert isinstance(value,dict); assert all(isinstance(k,str) and isinstance(v,str) for k,v in value.items())' \
    "${environment_json}"

mojo_ios_select_apple_toolchain
xcrun devicectl device info details --device "${device_id}" --timeout 20
xcrun devicectl device install app --device "${device_id}" "${app_path}"

mkdir -p "$(dirname "${log_path}")"
: >"${log_path}"
console_process_id=""
launched_process_snapshot_path="$(
  mktemp "${TMPDIR:-/tmp}/mojo-ios-process-snapshot.XXXXXX"
)"
launched_process_ids_path="$(
  mktemp "${TMPDIR:-/tmp}/mojo-ios-launched-processes.XXXXXX"
)"

resolve_launched_process_ids() {
  local executable_name
  executable_name="$(
    /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
      "${app_path}/Info.plist"
  )"
  xcrun devicectl device info processes \
    --device "${device_id}" --search "${executable_name}" \
    --json-output "${launched_process_snapshot_path}" --quiet >/dev/null
  PROCESS_EXECUTABLE="${executable_name}" \
    python3 - "${launched_process_snapshot_path}" \
      >"${launched_process_ids_path}" <<'PY'
import json
import os
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
needle = os.environ["PROCESS_EXECUTABLE"].lower()
identifiers = set()

def walk(value):
    if isinstance(value, dict):
        rendered = json.dumps(value, sort_keys=True).lower()
        if needle in rendered:
            for key, child in value.items():
                normalized = key.lower().replace("_", "")
                if normalized in {"pid", "processidentifier"} and isinstance(child, int):
                    identifiers.add(child)
        for child in value.values():
            walk(child)
    elif isinstance(value, list):
        for child in value:
            walk(child)

walk(payload)
for identifier in sorted(identifiers):
    print(identifier)
PY
}

cleanup() {
  if [[ "${leave_running}" = 0 ]]; then
    resolve_launched_process_ids || true
    while IFS= read -r launched_process_id; do
      [[ -n "${launched_process_id}" ]] || continue
      xcrun devicectl device process terminate \
        --device "${device_id}" --pid "${launched_process_id}" \
        --timeout 20 >/dev/null 2>&1 || true
    done <"${launched_process_ids_path}"
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
  rm -f -- "${launched_process_snapshot_path}" "${launched_process_ids_path}"
}
trap cleanup EXIT

launch_arguments=(
  xcrun devicectl device process launch
  --device "${device_id}"
  --timeout "$((timeout_seconds + 30))"
  --console
  --terminate-existing
)
if [[ -n "${environment_json}" ]]; then
  launch_arguments+=(--environment-variables "${environment_json}")
fi
launch_arguments+=("${bundle_identifier}")
"${launch_arguments[@]}" >"${log_path}" 2>&1 &
console_process_id=$!

"${project_root}/scripts/wait-for-marker.sh" \
  --log "${log_path}" \
  --literal "${expected_marker}" \
  --timeout "${timeout_seconds}" \
  --process "${console_process_id}"
cat "${log_path}"
printf 'DEVICE_APP_PASS device=%s bundle=%s cleanup=%s\n' \
  "${device_id}" "${bundle_identifier}" \
  "$([[ "${leave_running}" = 0 ]] && echo terminated || echo left-running)"
