#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/mojo-ios-shared-tooling.XXXXXX")"
case "${temporary_root}" in
"${TMPDIR:-/tmp}"/mojo-ios-shared-tooling.*) ;;
*) echo "refusing unexpected temporary path: ${temporary_root}" >&2; exit 1 ;;
esac
cleanup() {
  rm -rf -- "${temporary_root}"
}
trap cleanup EXIT

for relative_script_path in \
  scripts/lib/apple-toolchain.sh \
  scripts/lib/source-mojo.sh \
  scripts/resolve-apple-toolchain.sh \
  scripts/run-source-mojo.sh \
  scripts/build-embedded-apple-runtime.sh \
  scripts/wait-for-marker.sh \
  scripts/run-simulator-app.sh \
  scripts/run-device-app.sh; do
  bash -n "${project_root}/${relative_script_path}"
  case "${relative_script_path}" in
  scripts/lib/*) ;;
  *) "${project_root}/${relative_script_path}" --help >/dev/null ;;
  esac
done

python_scripts=(
  audit-ordinary-mojo-source.py
  audit-upstream-surface.py
  audit-macho-contract.py
  record-gate-evidence.py
)
for script_path in "${python_scripts[@]}"; do
  python3 -m py_compile "${project_root}/scripts/${script_path}"
  "${project_root}/scripts/${script_path}" --help >/dev/null
done

"${project_root}/scripts/resolve-apple-toolchain.sh" \
  --format json --require-metal >"${temporary_root}/toolchain.json"
python3 - "${temporary_root}/toolchain.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["developer_directory"]
assert payload["xcode_version"]
assert payload["metal_frontend"]
assert payload["metal_version"]
PY

"${project_root}/scripts/run-source-mojo.sh" \
  --state shared-tooling -- --version \
  >"${temporary_root}/mojo-version.out" 2>"${temporary_root}/mojo-version.err"
grep -Fq 'Mojo ' "${temporary_root}/mojo-version.out"

runtime_root="${temporary_root}/runtime"
"${project_root}/scripts/build-embedded-apple-runtime.sh" \
  --sdk macosx \
  --target-triple arm64-apple-macos14.0 \
  --optimization 0 \
  --output-directory "${runtime_root}" >/dev/null
"${project_root}/scripts/audit-macho-contract.py" \
  "${runtime_root}/CompilerRT.o" \
  --expect-platform macos \
  --require-defined KGEN_CompilerRT_Initialize >/dev/null
"${project_root}/scripts/audit-macho-contract.py" \
  "${runtime_root}/DeviceContext.o" \
  --expect-platform macos \
  --require-defined AsyncRT_DeviceContext_create >/dev/null

printf 'fn ordinary_fixture():\n    pass\n' >"${temporary_root}/ordinary.mojo"
"${project_root}/scripts/audit-ordinary-mojo-source.py" \
  "${temporary_root}/ordinary.mojo" >/dev/null
printf 'fn specialized_fixture():\n    if CompilationTarget.is_ios():\n        pass\n' \
  >"${temporary_root}/specialized.mojo"
if "${project_root}/scripts/audit-ordinary-mojo-source.py" \
    "${temporary_root}/specialized.mojo" \
    >"${temporary_root}/ordinary-negative.out" 2>&1; then
  echo "ordinary-Mojo source audit accepted an iOS target branch" >&2
  exit 1
fi
grep -Fq 'iOS target branch' "${temporary_root}/ordinary-negative.out"

cat >"${temporary_root}/macho.c" <<'EOF'
#include <stdio.h>
int mojo_ios_tooling_defined(void) {
  return puts("tooling");
}
EOF
xcrun --sdk macosx clang -target arm64-apple-macos14.0 \
  -c "${temporary_root}/macho.c" -o "${temporary_root}/macho.o"
"${project_root}/scripts/audit-macho-contract.py" \
  "${temporary_root}/macho.o" \
  --expect-platform macos \
  --require-defined mojo_ios_tooling_defined \
  --require-undefined puts >/dev/null
if "${project_root}/scripts/audit-macho-contract.py" \
    "${temporary_root}/macho.o" \
    --forbid-undefined-regex '^puts$' \
    >"${temporary_root}/macho-negative.out" 2>&1; then
  echo "Mach-O contract audit accepted a forbidden symbol" >&2
  exit 1
fi
grep -Fq 'forbidden undefined symbol: puts' "${temporary_root}/macho-negative.out"

marker_log="${temporary_root}/marker.log"
: >"${marker_log}"
(
  sleep 1
  printf 'SHARED_TOOLING_MARKER\n' >>"${marker_log}"
) &
marker_writer=$!
"${project_root}/scripts/wait-for-marker.sh" \
  --log "${marker_log}" --literal SHARED_TOOLING_MARKER \
  --timeout 5 --process "${marker_writer}"
wait "${marker_writer}"

DEVELOPER_DIR="$(
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["developer_directory"])' \
    "${temporary_root}/toolchain.json"
)" "${project_root}/scripts/record-gate-evidence.py" \
  --gate shared-tooling-self-test \
  --result pass \
  --field target=macos-arm64 \
  --command 'audit shared tooling' \
  --artifact "${temporary_root}/macho.o" \
  --output "${temporary_root}/evidence.json" >/dev/null
python3 - "${temporary_root}/evidence.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["kind"] == "mojo-ios-gate-evidence"
assert payload["result"] == "pass"
assert payload["fields"]["target"] == "macos-arm64"
assert len(payload["artifacts"]) == 1
PY

"${project_root}/scripts/audit-upstream-surface.py" \
  --json-output "${temporary_root}/upstream-surface.json" \
  >"${temporary_root}/upstream-surface.out"
python3 - "${temporary_root}/upstream-surface.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["forbidden_additions"] == []
assert isinstance(payload["added_declarations"], list)
PY

echo "SHARED_TOOLING_TEST_PASS toolchain=resolved metal=direct source_mojo=isolated runtime=canonical source_policy=yes macho=yes marker=yes evidence=yes upstream_surface=yes"
