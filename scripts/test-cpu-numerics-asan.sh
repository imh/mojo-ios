#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
build_root="${project_root}/build/cpu-numerics-asan"
compiler_state_root="${project_root}/build/compiler-state/cpu-numerics-asan"
sanitizer_clang="${MOJO_IOS_SANITIZER_CLANG:-$(command -v clang)}"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -x "${sanitizer_clang}"
sanitizer_runtime="$(${sanitizer_clang} -print-file-name=libclang_rt.asan_osx_dynamic.dylib)"
test -f "${sanitizer_runtime}"
nm -gU "${sanitizer_runtime}" | grep -Fq '___asan_version_mismatch_check_v8'
mkdir -p "${build_root}" "${compiler_state_root}/data" "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

numeric_object="${build_root}/VectorizedMemory.o"
"${compiler_command[@]}" build \
  "${project_root}/tests/cpu-conformance/VectorizedMemory.mojo" \
  -I "${stdlib_path}" \
  --target-triple=arm64-apple-macos14.0 \
  --target-cpu=generic \
  --optimization-level=3 \
  --sanitize=address \
  --emit object \
  -o "${numeric_object}"
nm -u "${numeric_object}" | grep -Eq '___asan_(load|store|report)'

runtime_sources=(
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"
)
runtime_names=(CompilerRT Globals KGENAsyncRT AppleWorkQueue DeviceContext)
runtime_objects=()
for runtime_index in "${!runtime_sources[@]}"; do
  runtime_object="${build_root}/${runtime_names[${runtime_index}]}.o"
  "${sanitizer_clang}" \
    -target arm64-apple-macos14.0 \
    -O3 -g -fsanitize=address \
    -std=c17 -Wall -Wextra -Werror \
    -I "${upstream_root}" \
    -I "${upstream_root}/AsyncRT/include" \
    -c "${runtime_sources[${runtime_index}]}" \
    -o "${runtime_object}"
  runtime_objects+=("${runtime_object}")
done

runner_path="${build_root}/CPUNumericsASan"
"${sanitizer_clang}" \
  -target arm64-apple-macos14.0 \
  -O3 -g -fsanitize=address \
  -std=c17 -Wall -Wextra -Werror \
  "${project_root}/tests/cpu-conformance/NumericASanRunner.c" \
  "${numeric_object}" \
  "${runtime_objects[@]}" \
  -o "${runner_path}"
ASAN_OPTIONS="abort_on_error=1:halt_on_error=1" "${runner_path}"
