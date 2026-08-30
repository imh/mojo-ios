#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build/host"
test_binary="${build_root}/MojoIOSAsyncRTTests"
upstream_root="${project_root}/.work/modular"

command -v xcrun >/dev/null
mkdir -p "${build_root}"

xcrun --sdk macosx clang \
  -fobjc-arc \
  -std=c17 \
  -O2 \
  -Wall \
  -Wextra \
  -Werror \
  -DASYNCRT_ENABLE_TESTING=1 \
  -DASYNCRT_ENABLE_METAL=1 \
  -I "${upstream_root}" \
  -I "${upstream_root}/AsyncRT/include" \
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c" \
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c" \
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c" \
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c" \
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c" \
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/MetalDeviceContextCAPI.m" \
  "${project_root}/Tests/MojoIOSAsyncRTTests.c" \
  -framework Foundation \
  -framework Metal \
  -o "${test_binary}"

"${test_binary}"
