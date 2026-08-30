#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compiler_path="${MOJO_IOS_MOJO_BINARY:?set MOJO_IOS_MOJO_BINARY to the source-built compiler}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:?set MOJO_IOS_STDLIB_PATH to the patched stdlib source root}"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
probe_path="${project_root}/probes/SupportedAppleRuntimeSurfaceProbe.mojo"
build_root="${project_root}/build/probes/supported-runtime-surface"
compiler_state_root="${project_root}/build/compiler-state/supported-runtime-surface"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -f "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
mkdir -p "${build_root}" "${compiler_state_root}/data" \
  "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

compile_and_link_variant() {
  local variant_name="$1"
  local sdk_name="$2"
  local target_triple="$3"
  local object_path="${build_root}/${variant_name}.o"
  local runtime_library_path="${build_root}/libEmbeddedRuntime-${variant_name}.a"

  "${compiler_command[@]}" build "${probe_path}" \
    -I "${stdlib_path}" \
    --target-triple="${target_triple}" \
    --target-cpu=generic \
    --optimization-level=3 \
    --emit object \
    -o "${object_path}"

  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -std=c17 \
    -O3 \
    -Wall \
    -Wextra \
    -Werror \
    -c "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c" \
    -o "${build_root}/CompilerRT-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -std=c17 \
    -O3 \
    -Wall \
    -Wextra \
    -Werror \
    -c "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c" \
    -o "${build_root}/Globals-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -std=c17 \
    -O3 \
    -Wall \
    -Wextra \
    -Werror \
    -I "${upstream_root}" \
    -c "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c" \
    -o "${build_root}/KGENAsyncRT-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -std=c17 \
    -O3 \
    -Wall \
    -Wextra \
    -Werror \
    -c "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c" \
    -o "${build_root}/AppleWorkQueue-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -std=c17 \
    -O3 \
    -Wall \
    -Wextra \
    -Werror \
    -I "${upstream_root}/AsyncRT/include" \
    -c "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c" \
    -o "${build_root}/DeviceContext-${variant_name}.o"

  xcrun ar rcs "${runtime_library_path}" \
    "${build_root}/CompilerRT-${variant_name}.o" \
    "${build_root}/Globals-${variant_name}.o" \
    "${build_root}/KGENAsyncRT-${variant_name}.o" \
    "${build_root}/AppleWorkQueue-${variant_name}.o" \
    "${build_root}/DeviceContext-${variant_name}.o"

  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -dynamiclib \
    -Wl,-undefined,error \
    "${object_path}" \
    -Wl,-force_load,"${runtime_library_path}" \
    -o "${build_root}/SupportedRuntimeSurface-${variant_name}.dylib"
}

compile_and_link_variant iphoneos iphoneos arm64-apple-ios15.0
compile_and_link_variant iphonesimulator iphonesimulator \
  arm64-apple-ios15.0-simulator

echo "verified normal stdlib runtime surface links for iOS device and simulator"
