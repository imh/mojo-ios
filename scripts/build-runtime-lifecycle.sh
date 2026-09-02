#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
max_mojo_path="${MOJO_IOS_MAX_MOJO_PATH:-${upstream_root}/max/mojo}"
build_root="${project_root}/build/runtime-lifecycle"
compiler_state_root="${project_root}/build/compiler-state/runtime-lifecycle"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_mojo_path}/max"
test -d "${developer_directory}"
export DEVELOPER_DIR="${developer_directory}"

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

verify_composed_binary() {
  local binary_path="$1"
  local map_path="$2"
  local runtime_definition_count
  runtime_definition_count="$(
    nm -gU "${binary_path}" |
      awk '$NF == "_KGEN_CompilerRT_Initialize" {count += 1} END {print count + 0}'
  )"
  test "${runtime_definition_count}" = 1
  if nm -u "${binary_path}" |
    grep -E '_(KGEN_CompilerRT_|AsyncRT_Device|AsyncRT_Apple)' >/dev/null; then
    echo "composed lifecycle binary retained an unresolved runtime operation" >&2
    exit 1
  fi
  if nm -gU "${binary_path}" | grep -E 'AsyncRT_Test_|mojo_ios_.*runtime' >/dev/null; then
    echo "composed lifecycle binary exposes a test or project runtime ABI" >&2
    exit 1
  fi
  test -s "${map_path}"
  local compiler_rt_member_count
  compiler_rt_member_count="$(
    grep -Ec 'libLifecycle[AB]\.a\(CompilerRT\.o\)' "${map_path}" || true
  )"
  test "${compiler_rt_member_count}" = 1
}

build_variant() {
  local variant_name="$1"
  local sdk_name="$2"
  local target_triple="$3"
  local optimization_level="$4"
  local variant_root="${build_root}/${variant_name}-o${optimization_level}"
  local debug_level=none
  if [[ "${optimization_level}" = 0 ]]; then
    debug_level=full
  fi
  mkdir -p "${variant_root}/library-a" "${variant_root}/library-b"

  local library_a_object="${variant_root}/library-a/LibraryA.o"
  local library_b_object="${variant_root}/library-b/LibraryB.o"
  "${compiler_command[@]}" build \
    "${project_root}/Tests/runtime-lifecycle/LibraryA.mojo" \
    -I "${stdlib_path}" \
    -I "${max_mojo_path}" \
    --target-triple="${target_triple}" \
    --target-cpu=generic \
    --optimization-level="${optimization_level}" \
    --debug-level="${debug_level}" \
    --emit object \
    -o "${library_a_object}"
  "${compiler_command[@]}" build \
    "${project_root}/Tests/runtime-lifecycle/LibraryB.mojo" \
    -I "${stdlib_path}" \
    -I "${max_mojo_path}" \
    --target-triple="${target_triple}" \
    --target-cpu=generic \
    --optimization-level="${optimization_level}" \
    --debug-level="${debug_level}" \
    --emit object \
    -o "${library_b_object}"

  if nm -u "${library_a_object}" "${library_b_object}" |
    grep -E '_mojo_ios_.*runtime' >/dev/null; then
    echo "lifecycle Mojo fixture depends on a project-specific runtime ABI" >&2
    exit 1
  fi
  if rg -n \
    'CompilationTarget\.is_ios|target\.is_ios|ios_parallel|mojo_ios_runtime' \
    "${project_root}/Tests/runtime-lifecycle"/*.mojo; then
    echo "lifecycle Mojo fixture contains an iOS-specific source path" >&2
    exit 1
  fi

  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -O"${optimization_level}" \
    -std=c17 -Wall -Wextra -Werror \
    -c "${project_root}/Tests/runtime-lifecycle/LifecycleSupport.c" \
    -o "${variant_root}/library-b/LifecycleSupport.o"
  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -O"${optimization_level}" \
    -std=c17 -Wall -Wextra -Werror \
    -I "${project_root}/include" \
    -I "${upstream_root}" \
    -I "${upstream_root}/AsyncRT/include" \
    -c "${project_root}/Tests/runtime-lifecycle/LifecycleRunner.c" \
    -o "${variant_root}/LifecycleRunner.o"

  for library_name in a b; do
    for runtime_index in "${!runtime_sources[@]}"; do
      xcrun --sdk "${sdk_name}" clang \
        -target "${target_triple}" \
        -O"${optimization_level}" \
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
    "${library_a_object}" \
    "${variant_root}/library-a/CompilerRT.o" \
    "${variant_root}/library-a/Globals.o" \
    "${variant_root}/library-a/KGENAsyncRT.o" \
    "${variant_root}/library-a/AppleWorkQueue.o" \
    "${variant_root}/library-a/DeviceContext.o"
  xcrun libtool -static -D -o "${library_b_path}" \
    "${library_b_object}" \
    "${variant_root}/library-b/LifecycleSupport.o" \
    "${variant_root}/library-b/CompilerRT.o" \
    "${variant_root}/library-b/Globals.o" \
    "${variant_root}/library-b/KGENAsyncRT.o" \
    "${variant_root}/library-b/AppleWorkQueue.o" \
    "${variant_root}/library-b/DeviceContext.o"
  xcrun libtool -static -D -o "${harness_path}" \
    "${variant_root}/LifecycleRunner.o"

  test "$(xcrun ar -t "${library_a_path}" | grep -vc '^__\.SYMDEF')" = 6
  test "$(xcrun ar -t "${library_b_path}" | grep -vc '^__\.SYMDEF')" = 7

  for link_order in ab ba; do
    local first_library="${library_a_path}"
    local second_library="${library_b_path}"
    if [[ "${link_order}" = ba ]]; then
      first_library="${library_b_path}"
      second_library="${library_a_path}"
    fi
    local composed_path="${variant_root}/Lifecycle-${link_order}.dylib"
    local map_path="${variant_root}/Lifecycle-${link_order}.map"
    xcrun --sdk "${sdk_name}" clang \
      -target "${target_triple}" \
      -dynamiclib \
      -Wl,-dead_strip \
      -Wl,-u,_mojo_ios_lifecycle_run_all \
      -Wl,-undefined,error \
      -Wl,-map,"${map_path}" \
      "${harness_path}" \
      "${first_library}" \
      "${second_library}" \
      -o "${composed_path}"
    verify_composed_binary "${composed_path}" "${map_path}"
  done

  if [[ "${sdk_name}" = macosx ]]; then
    for link_order in ab ba; do
      local first_library="${library_a_path}"
      local second_library="${library_b_path}"
      if [[ "${link_order}" = ba ]]; then
        first_library="${library_b_path}"
        second_library="${library_a_path}"
      fi
      local host_path="${variant_root}/LifecycleHost-${link_order}"
      local host_map_path="${variant_root}/LifecycleHost-${link_order}.map"
      xcrun --sdk macosx clang \
        -target "${target_triple}" \
        -O"${optimization_level}" \
        -std=c17 -Wall -Wextra -Werror \
        -I "${project_root}/include" \
        -Wl,-dead_strip \
        -Wl,-map,"${host_map_path}" \
        "${project_root}/Tests/runtime-lifecycle/HostMain.c" \
        "${harness_path}" \
        "${first_library}" \
        "${second_library}" \
        -o "${host_path}"
      verify_composed_binary "${host_path}" "${host_map_path}"
      "${host_path}"
    done
  fi
}

for optimization_level in 0 3; do
  build_variant macos macosx arm64-apple-macos14.0 "${optimization_level}"
  build_variant iphoneos iphoneos arm64-apple-ios15.0 "${optimization_level}"
  build_variant iphonesimulator iphonesimulator \
    arm64-apple-ios15.0-simulator "${optimization_level}"
done

echo "RUNTIME_LIFECYCLE_BUILD_PASS libraries=2 link_orders=ab,ba variants=3 optimizations=0,3 runtime_instances=1"
