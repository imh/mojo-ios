#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${project_root}/.work/modular"
build_root="${project_root}/build/host"
test_binary="${build_root}/EmbeddedCompilerRTTests"

command -v xcrun >/dev/null
mkdir -p "${build_root}"

xcrun --sdk macosx clang \
  -std=c17 \
  -O2 \
  -Wall \
  -Wextra \
  -Werror \
  -I "${upstream_root}" \
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c" \
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c" \
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c" \
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c" \
  "${project_root}/Tests/EmbeddedCompilerRTTests.c" \
  -o "${test_binary}"

"${test_binary}"
