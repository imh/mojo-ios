#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
build_root="${project_root}/build/cpu-conformance"
compiler_state_root="${project_root}/build/compiler-state/cpu-conformance"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${developer_directory}"
export DEVELOPER_DIR="${developer_directory}"

manifest_path="${project_root}/tests/cpu-conformance/manifest.tsv"
test -f "${manifest_path}"
IFS=$'\t' read -r family_header fixture_header provenance_header expected_header \
  <"${manifest_path}"
test "${family_header}" = family
test "${fixture_header}" = fixture
test "${provenance_header}" = upstream_provenance
test "${expected_header}" = expected

fixture_names=()
seen_fixture_names=" "
while IFS=$'\t' read -r family fixture_name upstream_provenance expected; do
  test -n "${family}"
  test -n "${fixture_name}"
  test -f "${project_root}/tests/cpu-conformance/${fixture_name}"
  test -f "${upstream_root}/${upstream_provenance}"
  [[ "${expected}" =~ ^-?[0-9]+$ ]]
  fixture_stem="${fixture_name%.mojo}"
  case "${seen_fixture_names}" in
    *" ${fixture_stem} "*)
      echo "duplicate CPU conformance fixture: ${fixture_name}" >&2
      exit 1
      ;;
  esac
  seen_fixture_names+="${fixture_stem} "
  fixture_names+=("${fixture_stem}")
done < <(tail -n +2 "${manifest_path}")
test "${#fixture_names[@]}" -gt 0
if rg -n \
    'CompilationTarget\.is_ios|target\.is_ios|ios_parallel|mojo_ios_runtime' \
    "${project_root}/tests/cpu-conformance"/*.mojo; then
  echo "CPU conformance fixtures contain an iOS-specific Mojo source path" >&2
  exit 1
fi
runtime_sources=(
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"
)
for runtime_source in "${runtime_sources[@]}"; do
  test -f "${runtime_source}"
done

mkdir -p \
  "${compiler_state_root}/data" \
  "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

build_variant() {
  local variant_name="$1"
  local sdk_name="$2"
  local target_triple="$3"
  local optimization_level="$4"
  local variant_root="${build_root}/${variant_name}-o${optimization_level}"
  local debug_level="none"
  if [[ "${optimization_level}" = "0" ]]; then
    debug_level="full"
  fi
  mkdir -p "${variant_root}"

  local fixture_objects=()
  for fixture_name in "${fixture_names[@]}"; do
    local fixture_object="${variant_root}/${fixture_name}.o"
    "${compiler_command[@]}" build \
      "${project_root}/tests/cpu-conformance/${fixture_name}.mojo" \
      -I "${stdlib_path}" \
      --target-triple="${target_triple}" \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --debug-level="${debug_level}" \
      --emit object \
      -o "${fixture_object}"
    fixture_objects+=("${fixture_object}")
  done

  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -O"${optimization_level}" \
    -std=c17 -Wall -Wextra -Werror \
    -I "${project_root}/include" \
    -c "${project_root}/tests/cpu-conformance/ConformanceSupport.c" \
    -o "${variant_root}/ConformanceSupport.o"

  local runtime_objects=()
  local runtime_names=(CompilerRT Globals KGENAsyncRT AppleWorkQueue DeviceContext)
  local runtime_index=0
  for runtime_source in "${runtime_sources[@]}"; do
    local runtime_object="${variant_root}/${runtime_names[${runtime_index}]}.o"
    xcrun --sdk "${sdk_name}" clang \
      -target "${target_triple}" \
      -O"${optimization_level}" \
      -std=c17 -Wall -Wextra -Werror \
      -I "${upstream_root}" \
      -I "${upstream_root}/AsyncRT/include" \
      -c "${runtime_source}" \
      -o "${runtime_object}"
    runtime_objects+=("${runtime_object}")
    runtime_index=$((runtime_index + 1))
  done

  for fixture_name in "${fixture_names[@]}"; do
    xcrun --sdk "${sdk_name}" clang \
      -target "${target_triple}" \
      -dynamiclib \
      -Wl,-undefined,error \
      "${variant_root}/${fixture_name}.o" \
      "${variant_root}/ConformanceSupport.o" \
      "${runtime_objects[@]}" \
      -o "${variant_root}/${fixture_name}.dylib"
    if nm -u "${variant_root}/${fixture_name}.dylib" |
      grep -E '_(KGEN_CompilerRT_|AsyncRT_Device)' >/dev/null; then
      echo "${fixture_name} retained an embedded runtime dependency after full linkage" >&2
      exit 1
    fi
    if nm -u "${variant_root}/${fixture_name}.o" |
      grep -E '_mojo_ios_.*runtime' >/dev/null; then
      echo "${fixture_name} depends on a project-specific Mojo runtime ABI" >&2
      exit 1
    fi
  done

  local library_path="${variant_root}/libCPUConformance.a"
  rm -f -- "${library_path}"
  xcrun libtool -static -D -o "${library_path}" \
    "${fixture_objects[@]}" \
    "${variant_root}/ConformanceSupport.o" \
    "${runtime_objects[@]}"

  if [[ "${sdk_name}" = "macosx" ]]; then
    xcrun --sdk macosx clang \
      -target "${target_triple}" \
      -O"${optimization_level}" \
      -std=c17 -Wall -Wextra -Werror \
      -I "${project_root}/include" \
      "${project_root}/tests/cpu-conformance/HostRunner.c" \
      "${library_path}" \
      -o "${variant_root}/CPUConformanceHost"
    "${variant_root}/CPUConformanceHost"
  fi
}

for optimization_level in 0 3; do
  build_variant macos macosx arm64-apple-macos14.0 "${optimization_level}"
  build_variant iphoneos iphoneos arm64-apple-ios15.0 "${optimization_level}"
  build_variant iphonesimulator iphonesimulator \
    arm64-apple-ios15.0-simulator "${optimization_level}"
done

echo "CPU_CONFORMANCE_BUILD_PASS families=${#fixture_names[@]} variants=3 optimizations=0,3 independent_link=yes"
