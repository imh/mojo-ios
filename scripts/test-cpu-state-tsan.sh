#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
max_mojo_path="${MOJO_IOS_MAX_MOJO_PATH:-${upstream_root}/max/mojo}"
build_root="${project_root}/build/cpu-state-tsan"
compiler_state_root="${project_root}/build/compiler-state/cpu-state-tsan"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_mojo_path}/max"
mkdir -p "${build_root}" "${compiler_state_root}/data" "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

atomic_object="${build_root}/AtomicConcurrency.o"
"${compiler_command[@]}" build \
  "${project_root}/tests/cpu-conformance/AtomicConcurrency.mojo" \
  -I "${stdlib_path}" \
  -I "${max_mojo_path}" \
  --target-triple=arm64-apple-macos14.0 \
  --target-cpu=generic \
  --optimization-level=3 \
  --sanitize=thread \
  --emit object \
  -o "${atomic_object}"
nm -u "${atomic_object}" | grep -Eq '___tsan_(func_entry|read|write)'

runtime_sources=(
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"
)
runtime_objects=()
runtime_names=(CompilerRT Globals KGENAsyncRT AppleWorkQueue DeviceContext)
for runtime_index in "${!runtime_sources[@]}"; do
  runtime_object="${build_root}/${runtime_names[${runtime_index}]}.o"
  xcrun --sdk macosx clang \
    -target arm64-apple-macos14.0 \
    -O3 -g \
    -fsanitize=thread \
    -std=c17 -Wall -Wextra -Werror \
    -I "${upstream_root}" \
    -I "${upstream_root}/AsyncRT/include" \
    -c "${runtime_sources[${runtime_index}]}" \
    -o "${runtime_object}"
  runtime_objects+=("${runtime_object}")
done

runner_path="${build_root}/CPUStateTSan"
xcrun --sdk macosx clang \
  -target arm64-apple-macos14.0 \
  -O3 -g \
  -fsanitize=thread \
  -std=c17 -Wall -Wextra -Werror \
  "${project_root}/tests/cpu-conformance/AtomicTSanRunner.c" \
  "${atomic_object}" \
  "${runtime_objects[@]}" \
  -o "${runner_path}"

TSAN_OPTIONS="halt_on_error=1:abort_on_error=1" "${runner_path}"
