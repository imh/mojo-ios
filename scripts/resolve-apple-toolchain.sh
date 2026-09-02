#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"

output_format=text
require_metal=0

usage() {
  cat <<'EOF'
Usage: resolve-apple-toolchain.sh [--format text|json|shell] [--require-metal]

Selects the repository-approved Xcode without changing global xcode-select.
An explicit DEVELOPER_DIR wins. Otherwise stable Xcode is used only when it
reports version 27 or newer; Xcode-beta is the fallback.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --format)
    [[ $# -ge 2 ]] || { usage >&2; exit 2; }
    output_format="$2"
    shift 2
    ;;
  --require-metal)
    require_metal=1
    shift
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

case "${output_format}" in
text|json|shell) ;;
*) echo "unsupported output format: ${output_format}" >&2; exit 2 ;;
esac

mojo_ios_select_apple_toolchain
if [[ "${require_metal}" = 1 ]]; then
  mojo_ios_discover_metal_frontend
fi

case "${output_format}" in
text)
  printf 'DEVELOPER_DIR=%s\n%s\n' \
    "${DEVELOPER_DIR}" "${MOJO_IOS_SELECTED_XCODE_VERSION}"
  if [[ "${require_metal}" = 1 ]]; then
    printf 'METAL_FRONTEND=%s\n%s\n' \
      "${MOJO_IOS_METAL_FRONTEND}" "${MOJO_IOS_METAL_VERSION}"
  fi
  ;;
shell)
  printf 'export DEVELOPER_DIR=%q\n' "${DEVELOPER_DIR}"
  printf 'export MOJO_IOS_SELECTED_XCODE_MAJOR=%q\n' \
    "${MOJO_IOS_SELECTED_XCODE_MAJOR}"
  if [[ "${require_metal}" = 1 ]]; then
    printf 'export MOJO_IOS_METAL_FRONTEND=%q\n' \
      "${MOJO_IOS_METAL_FRONTEND}"
  fi
  ;;
json)
  DEVELOPER_DIR_VALUE="${DEVELOPER_DIR}" \
  XCODE_VERSION_VALUE="${MOJO_IOS_SELECTED_XCODE_VERSION}" \
  METAL_FRONTEND_VALUE="${MOJO_IOS_METAL_FRONTEND:-}" \
  METAL_VERSION_VALUE="${MOJO_IOS_METAL_VERSION:-}" \
    python3 - <<'PY'
import json
import os

print(json.dumps({
    "developer_directory": os.environ["DEVELOPER_DIR_VALUE"],
    "xcode_version": os.environ["XCODE_VERSION_VALUE"].splitlines(),
    "metal_frontend": os.environ["METAL_FRONTEND_VALUE"] or None,
    "metal_version": os.environ["METAL_VERSION_VALUE"].splitlines() or None,
}, sort_keys=True, indent=2))
PY
  ;;
esac
