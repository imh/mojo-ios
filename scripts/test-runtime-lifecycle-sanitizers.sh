#!/bin/bash
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
max_mojo_path="${MOJO_IOS_MAX_MOJO_PATH:-${upstream_root}/max/mojo}"
build_root="${project_root}/build/runtime-lifecycle-sanitizers"
compiler_state_root="${project_root}/build/compiler-state/runtime-lifecycle-sanitizers"
address_clang="${MOJO_IOS_SANITIZER_CLANG:-$(command -v clang)}"
thread_clang="$(xcrun --sdk macosx --find clang)"
macos_sdk_path="$(xcrun --sdk macosx --show-sdk-path)"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_mojo_path}/max"
test -x "${address_clang}"
test -x "${thread_clang}"
mkdir -p \
  "${build_root}" \
  "${compiler_state_root}/data" \
  "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

runtime_sources=(
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"
)
runtime_names=(CompilerRT Globals KGENAsyncRT AppleWorkQueue DeviceContext)

build_sanitized_variant() {
  local sanitizer_name="$1"
  local sanitizer_flag="$2"
  local clang_path="$3"
  local optimization_level="$4"
  local variant_root="${build_root}/${sanitizer_name}-o${optimization_level}"
  mkdir -p "${variant_root}/library-a" "${variant_root}/library-b"

  for library_name in A B; do
    local library_directory=library-a
    if [[ "${library_name}" = B ]]; then
      library_directory=library-b
    fi
    "${compiler_command[@]}" build \
      "${project_root}/Tests/runtime-lifecycle/Library${library_name}.mojo" \
      -I "${stdlib_path}" \
      -I "${max_mojo_path}" \
      --target-triple=arm64-apple-macos14.0 \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --sanitize="${sanitizer_name}" \
      --emit object \
      -o "${variant_root}/${library_directory}/Library${library_name}.o"
  done
  if [[ "${sanitizer_name}" = address ]]; then
    nm -u "${variant_root}/library-a/LibraryA.o" \
      "${variant_root}/library-b/LibraryB.o" | grep -Eq '___asan_(load|store|report)'
  else
    nm -u "${variant_root}/library-a/LibraryA.o" \
      "${variant_root}/library-b/LibraryB.o" | grep -Eq '___tsan_(func_entry|read|write)'
  fi

  "${clang_path}" \
    -target arm64-apple-macos14.0 \
    -isysroot "${macos_sdk_path}" \
    -O"${optimization_level}" -g "${sanitizer_flag}" \
    -std=c17 -Wall -Wextra -Werror \
    -c "${project_root}/Tests/runtime-lifecycle/LifecycleSupport.c" \
    -o "${variant_root}/library-b/LifecycleSupport.o"
  "${clang_path}" \
    -target arm64-apple-macos14.0 \
    -isysroot "${macos_sdk_path}" \
    -O"${optimization_level}" -g "${sanitizer_flag}" \
    -std=c17 -Wall -Wextra -Werror \
    -I "${project_root}/include" \
    -I "${upstream_root}" \
    -I "${upstream_root}/AsyncRT/include" \
    -c "${project_root}/Tests/runtime-lifecycle/LifecycleRunner.c" \
    -o "${variant_root}/LifecycleRunner.o"

  for library_name in a b; do
    for runtime_index in "${!runtime_sources[@]}"; do
      "${clang_path}" \
        -target arm64-apple-macos14.0 \
        -isysroot "${macos_sdk_path}" \
        -O"${optimization_level}" -g "${sanitizer_flag}" \
        -std=c17 -Wall -Wextra -Werror \
        -I "${upstream_root}" \
        -I "${upstream_root}/AsyncRT/include" \
        -c "${runtime_sources[${runtime_index}]}" \
        -o "${variant_root}/library-${library_name}/${runtime_names[${runtime_index}]}.o"
    done
  done

  local library_a_path="${variant_root}/libLifecycleA.a"
  local library_b_path="${variant_root}/libLifecycleB.a"
  local harness_path="${variant_root}/libLifecycleHarness.a"
  /bin/rm -f -- "${library_a_path}" "${library_b_path}" "${harness_path}"
  xcrun libtool -static -D -o "${library_a_path}" \
    "${variant_root}/library-a/LibraryA.o" \
    "${variant_root}/library-a/CompilerRT.o" \
    "${variant_root}/library-a/Globals.o" \
    "${variant_root}/library-a/KGENAsyncRT.o" \
    "${variant_root}/library-a/AppleWorkQueue.o" \
    "${variant_root}/library-a/DeviceContext.o"
  xcrun libtool -static -D -o "${library_b_path}" \
    "${variant_root}/library-b/LibraryB.o" \
    "${variant_root}/library-b/LifecycleSupport.o" \
    "${variant_root}/library-b/CompilerRT.o" \
    "${variant_root}/library-b/Globals.o" \
    "${variant_root}/library-b/KGENAsyncRT.o" \
    "${variant_root}/library-b/AppleWorkQueue.o" \
    "${variant_root}/library-b/DeviceContext.o"
  xcrun libtool -static -D -o "${harness_path}" \
    "${variant_root}/LifecycleRunner.o"

  for link_order in ab ba; do
    local first_library="${library_a_path}"
    local second_library="${library_b_path}"
    if [[ "${link_order}" = ba ]]; then
      first_library="${library_b_path}"
      second_library="${library_a_path}"
    fi
    local runner_path="${variant_root}/LifecycleHost-${link_order}"
    "${clang_path}" \
      -target arm64-apple-macos14.0 \
      -isysroot "${macos_sdk_path}" \
      -O"${optimization_level}" -g "${sanitizer_flag}" \
      -std=c17 -Wall -Wextra -Werror \
      -I "${project_root}/include" \
      "${project_root}/Tests/runtime-lifecycle/HostMain.c" \
      "${harness_path}" \
      "${first_library}" \
      "${second_library}" \
      -o "${runner_path}"
    if nm -gU "${runner_path}" |
      awk '$NF == "_KGEN_CompilerRT_Initialize" {count += 1} END {exit count != 1}'; then
      :
    else
      echo "sanitized composition did not contain exactly one runtime" >&2
      exit 1
    fi
    if [[ "${sanitizer_name}" = address ]]; then
      ASAN_OPTIONS="abort_on_error=1:halt_on_error=1:detect_leaks=1" \
        "${runner_path}"
    else
      TSAN_OPTIONS="halt_on_error=1:abort_on_error=1" "${runner_path}"
    fi
  done
}

for optimization_level in 0 3; do
  build_sanitized_variant address -fsanitize=address \
    "${address_clang}" "${optimization_level}"
  build_sanitized_variant thread -fsanitize=thread \
    "${thread_clang}" "${optimization_level}"
done

echo "RUNTIME_LIFECYCLE_SANITIZER_PASS sanitizers=asan,tsan optimizations=0,3 link_orders=ab,ba mojo_instrumented=yes test_controls=no"
