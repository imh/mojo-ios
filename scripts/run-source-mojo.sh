#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/source-mojo.sh"

usage() {
  cat <<'EOF'
Usage: run-source-mojo.sh --state NAME -- MOJO_ARGUMENTS...

Runs the pinned source-built Mojo compiler with isolated compiler state.
Target, optimization, sanitizer, include, and output arguments remain explicit.
EOF
}

state_namespace=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --state)
    [[ $# -ge 2 ]] || { usage >&2; exit 2; }
    state_namespace="$2"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    echo "unknown launcher argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

[[ -n "${state_namespace}" ]] || { usage >&2; exit 2; }
[[ $# -gt 0 ]] || { usage >&2; exit 2; }
mojo_ios_configure_source_mojo "${project_root}" "${state_namespace}"
mojo_ios_source_mojo "$@"
