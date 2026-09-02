#!/bin/bash
set -euo pipefail

log_path=""
literal_marker=""
timeout_seconds=30
process_id=""

usage() {
  cat <<'EOF'
Usage: wait-for-marker.sh --log PATH --literal TEXT [--timeout SECONDS] [--process PID]

Waits for an exact literal in a growing log. Fails distinctly when the watched
process exits first or the timeout expires, and prints a bounded diagnostic tail.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --log) log_path="${2:-}"; shift 2 ;;
  --literal) literal_marker="${2:-}"; shift 2 ;;
  --timeout) timeout_seconds="${2:-}"; shift 2 ;;
  --process) process_id="${2:-}"; shift 2 ;;
  --help|-h) usage; exit 0 ;;
  *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "${log_path}" && -n "${literal_marker}" ]] || { usage >&2; exit 2; }
[[ "${timeout_seconds}" =~ ^[1-9][0-9]*$ ]] || {
  echo "timeout must be a positive integer" >&2
  exit 2
}
if [[ -n "${process_id}" ]] && [[ ! "${process_id}" =~ ^[1-9][0-9]*$ ]]; then
  echo "process id must be a positive integer" >&2
  exit 2
fi

start_seconds="${SECONDS}"
while (( SECONDS - start_seconds < timeout_seconds )); do
  if [[ -f "${log_path}" ]] && grep -Fq -- "${literal_marker}" "${log_path}"; then
    exit 0
  fi
  if [[ -n "${process_id}" ]] && ! kill -0 "${process_id}" 2>/dev/null; then
    echo "watched process ${process_id} exited before marker: ${literal_marker}" >&2
    [[ ! -f "${log_path}" ]] || tail -n 200 "${log_path}" >&2
    exit 1
  fi
  sleep 0.25
done

echo "timed out after ${timeout_seconds}s waiting for marker: ${literal_marker}" >&2
if [[ -f "${log_path}" ]]; then
  tail -n 200 "${log_path}" >&2
else
  echo "log was never created: ${log_path}" >&2
fi
exit 1
