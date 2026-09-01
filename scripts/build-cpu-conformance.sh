#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
max_mojo_path="${MOJO_IOS_MAX_MOJO_PATH:-${upstream_root}/max/mojo}"
build_root="${project_root}/build/cpu-conformance"
compiler_state_root="${project_root}/build/compiler-state/cpu-conformance"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_mojo_path}/max"
test -d "${developer_directory}"
export DEVELOPER_DIR="${developer_directory}"

manifest_path="${project_root}/tests/cpu-conformance/manifest.tsv"
test -f "${manifest_path}"
IFS=$'\t' read -r family_header fixture_header symbol_header provenance_header \
  expected_header \
  <"${manifest_path}"
test "${family_header}" = family
test "${fixture_header}" = fixture
test "${symbol_header}" = symbol
test "${provenance_header}" = upstream_provenance
test "${expected_header}" = expected

fixture_names=()
seen_fixture_names=" "
while IFS=$'\t' read -r family fixture_name symbol upstream_provenance expected; do
  [[ "${family}" =~ ^[a-z0-9][a-z0-9-]*$ ]]
  [[ "${fixture_name}" =~ ^[a-zA-Z0-9_]+\.mojo$ ]]
  [[ "${symbol}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
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

generated_root="${build_root}/generated"
generated_runner_path="${generated_root}/GeneratedConformanceRunner.c"
mkdir -p "${generated_root}"
{
  printf '#include "CPUConformance.h"\n\n'
  printf '#include <inttypes.h>\n#include <stddef.h>\n#include <stdio.h>\n\n'
  while IFS=$'\t' read -r family fixture_name symbol upstream_provenance expected; do
    printf 'extern int64_t %s(void);\n' "${symbol}"
  done < <(tail -n +2 "${manifest_path}")
  printf '\ntypedef struct {\n'
  printf '  const char *family;\n  int64_t (*run)(void);\n  int64_t expected;\n'
  printf '} MojoIOSConformanceCase;\n\n'
  printf 'static const MojoIOSConformanceCase cases[] = {\n'
  while IFS=$'\t' read -r family fixture_name symbol upstream_provenance expected; do
    printf '  {"%s", %s, INT64_C(%s)},\n' "${family}" "${symbol}" "${expected}"
  done < <(tail -n +2 "${manifest_path}")
  printf '};\n\n'
  printf 'int64_t mojo_ios_conformance_family_count(void) {\n'
  printf '  return (int64_t)(sizeof(cases) / sizeof(cases[0]));\n}\n\n'
  printf 'int64_t mojo_ios_conformance_run_all(void) {\n'
  printf '  for (size_t index = 0; index < sizeof(cases) / sizeof(cases[0]); ++index) {\n'
  printf '    const int64_t actual = cases[index].run();\n'
  printf '    if (actual != cases[index].expected) {\n'
  printf '      fprintf(stderr, "CPU conformance failure: %%s expected=%%" PRId64 " actual=%%" PRId64 "\\n", cases[index].family, cases[index].expected, actual);\n'
  printf '      return (int64_t)index + 1;\n'
  printf '    }\n  }\n  return 0;\n}\n'
} >"${generated_runner_path}"
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
      -I "${max_mojo_path}" \
      --target-triple="${target_triple}" \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --debug-level="${debug_level}" \
      --emit object \
      -o "${fixture_object}"
    fixture_objects+=("${fixture_object}")
  done
  if nm -u \
    "${variant_root}/Atomics.o" \
    "${variant_root}/AtomicConcurrency.o" | grep -Eq '___atomic_'; then
    echo "CPU atomics unexpectedly require an external atomic helper" >&2
    exit 1
  fi

  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -O"${optimization_level}" \
    -std=c17 -Wall -Wextra -Werror \
    -I "${project_root}/include" \
    -c "${project_root}/tests/cpu-conformance/ConformanceSupport.c" \
    -o "${variant_root}/ConformanceSupport.o"
  xcrun --sdk "${sdk_name}" clang \
    -target "${target_triple}" \
    -O"${optimization_level}" \
    -std=c17 -Wall -Wextra -Werror \
    -I "${project_root}/include" \
    -c "${generated_runner_path}" \
    -o "${variant_root}/GeneratedConformanceRunner.o"

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
    "${variant_root}/GeneratedConformanceRunner.o" \
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

verify_device_llvm() {
  local optimization_level="$1"
  local variant_root="${build_root}/iphoneos-o${optimization_level}"
  for fixture_name in GlobalConstants Atomics AtomicConcurrency; do
    "${compiler_command[@]}" build \
      "${project_root}/tests/cpu-conformance/${fixture_name}.mojo" \
      -I "${stdlib_path}" \
      -I "${max_mojo_path}" \
      --target-triple=arm64-apple-ios15.0 \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --emit llvm \
      -o "${variant_root}/${fixture_name}.ll"
  done

  local global_ir="${variant_root}/GlobalConstants.ll"
  local atomic_ir="${variant_root}/Atomics.ll"
  local concurrent_ir="${variant_root}/AtomicConcurrency.ll"
  test "$(grep -Ec '^@global_constant(_[0-9]+)? = internal constant' "${global_ir}")" -ge 1
  if grep -Fq '@llvm.global_ctors' "${global_ir}"; then
    echo "global_constant unexpectedly introduced a runtime global constructor" >&2
    exit 1
  fi
  grep -Eq 'load atomic i32, .* monotonic' "${atomic_ir}"
  grep -Eq 'store atomic i32 7, .* release' "${atomic_ir}"
  grep -Eq 'load atomic i32, .* acquire' "${atomic_ir}"
  grep -Eq 'atomicrmw add .* acq_rel' "${atomic_ir}"
  grep -Eq 'atomicrmw sub .* seq_cst' "${atomic_ir}"
  grep -Eq 'cmpxchg .* acq_rel acquire' "${atomic_ir}"
  grep -Eq 'cmpxchg .* seq_cst acquire' "${atomic_ir}"
  grep -Eq 'fence acq_rel' "${atomic_ir}"
  grep -Eq 'store atomic i32 1, .* release' "${concurrent_ir}"
  grep -Eq 'load atomic i32, .* acquire' "${concurrent_ir}"
}

for optimization_level in 0 3; do
  build_variant macos macosx arm64-apple-macos14.0 "${optimization_level}"
  build_variant iphoneos iphoneos arm64-apple-ios15.0 "${optimization_level}"
  build_variant iphonesimulator iphonesimulator \
    arm64-apple-ios15.0-simulator "${optimization_level}"
  verify_device_llvm "${optimization_level}"
done

echo "CPU_CONFORMANCE_BUILD_PASS families=${#fixture_names[@]} variants=3 optimizations=0,3 independent_link=yes"
