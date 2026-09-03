#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"
source "${project_root}/scripts/lib/source-mojo.sh"

build_root="${project_root}/build/cpu-core-language-lowering"
routing_path="${project_root}/config/cpu-language-family-routing.tsv"
mojo_ios_select_apple_toolchain
mojo_ios_configure_source_mojo "${project_root}" cpu-core-language-lowering
mkdir -p "${build_root}"

IFS=$'\t' read -r family_header paths_header route_header boundary_header \
  <"${routing_path}"
[[ "${family_header}" = family ]]
[[ "${paths_header}" = representative_paths ]]
[[ "${route_header}" = route ]]
[[ "${boundary_header}" = boundary ]]

family_count=0
seen_families=" "
while IFS=$'\t' read -r family representative_paths route boundary; do
  [[ "${family}" =~ ^[a-z0-9][a-z0-9-]*$ ]]
  [[ -n "${boundary}" ]]
  case "${seen_families}" in
    *" ${family} "*)
      echo "duplicate CPU language-family route: ${family}" >&2
      exit 1
      ;;
  esac
  seen_families+="${family} "
  case "${route}" in
    M2-portable-corpus|M2-closure-corpus|M3-stdlib-native|M6-async|M4-M5-accelerators|outside-shipped-AOT)
      ;;
    *)
      echo "unknown CPU language-family route: ${route}" >&2
      exit 1
      ;;
  esac
  IFS=',' read -r -a paths <<<"${representative_paths}"
  [[ "${#paths[@]}" -gt 0 ]]
  for relative_path in "${paths[@]}"; do
    [[ -e "${MOJO_IOS_UPSTREAM_ROOT}/${relative_path}" ]] || {
      echo "missing pinned upstream family source: ${relative_path}" >&2
      exit 1
    }
  done
  family_count=$((family_count + 1))
done < <(tail -n +2 "${routing_path}")
[[ "${family_count}" -ge 10 ]]

fixtures=(
  ControlFlow
  AggregateValues
  VariadicPacks
  IndirectCalls
  AggregateCallingConventions
)
exports=(
  mojo_ios_conformance_control_flow
  mojo_ios_conformance_aggregate_values
  mojo_ios_conformance_variadic_packs
  mojo_ios_conformance_indirect_calls
  mojo_ios_conformance_aggregate_calling_conventions
)

"${project_root}/scripts/audit-ordinary-mojo-source.py" \
  "${project_root}/tests/cpu-conformance"

expected_undefined_path="${build_root}/expected-undefined.txt"
printf '%s\n' \
  KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice \
  KGEN_CompilerRT_AsyncRT_GetOrCreateCPUDevice \
  KGEN_CompilerRT_AsyncRT_ReleaseCPUDevice \
  KGEN_CompilerRT_GetOrCreateGlobal \
  >"${expected_undefined_path}"

for optimization_level in 0 3; do
  for fixture_index in "${!fixtures[@]}"; do
    fixture_name="${fixtures[${fixture_index}]}"
    export_name="${exports[${fixture_index}]}"
    source_path="${project_root}/tests/cpu-conformance/${fixture_name}.mojo"
    llvm_path="${build_root}/${fixture_name}-o${optimization_level}.ll"
    object_path="${build_root}/${fixture_name}-o${optimization_level}.o"

    mojo_ios_source_mojo build \
      "${source_path}" \
      -I "${MOJO_IOS_STDLIB_PATH}" \
      -I "${MOJO_IOS_MAX_MOJO_PATH}" \
      --target-triple=arm64-apple-ios15.0 \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --emit llvm \
      -o "${llvm_path}"
    mojo_ios_source_mojo build \
      "${source_path}" \
      -I "${MOJO_IOS_STDLIB_PATH}" \
      -I "${MOJO_IOS_MAX_MOJO_PATH}" \
      --target-triple=arm64-apple-ios15.0 \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --emit object \
      -o "${object_path}"

    grep -Fq 'target triple = "arm64-apple-ios15.0"' "${llvm_path}"
    "${project_root}/scripts/audit-macho-contract.py" \
      "${object_path}" \
      --expect-platform ios \
      --require-defined "${export_name}" \
      --forbid-undefined-regex '^mojo_ios_' \
      --forbid-undefined-regex '^(__atomic_|__aeabi_|__gnu_)'

    actual_undefined_path="${build_root}/${fixture_name}-o${optimization_level}-undefined.txt"
    xcrun nm -u "${object_path}" |
      awk '{symbol=$NF; sub(/^_/, "", symbol); print symbol}' |
      LC_ALL=C sort -u >"${actual_undefined_path}"
    diff -u "${expected_undefined_path}" "${actual_undefined_path}"
  done

  control_flow_llvm="${build_root}/ControlFlow-o${optimization_level}.ll"
  aggregate_values_llvm="${build_root}/AggregateValues-o${optimization_level}.ll"
  variadic_llvm="${build_root}/VariadicPacks-o${optimization_level}.ll"
  indirect_llvm="${build_root}/IndirectCalls-o${optimization_level}.ll"

  grep -Fq 'define internal i64 @"ControlFlow::recursive_factorial' \
    "${control_flow_llvm}"
  grep -Fq 'call i64 @"ControlFlow::recursive_factorial' "${control_flow_llvm}"
  grep -Fq 'define internal { { i64, i64, i64 } } @"AggregateValues::make_values' \
    "${aggregate_values_llvm}"
  grep -Fq 'extractvalue { { i64, i64, i64 } }' "${aggregate_values_llvm}"
  grep -Eq 'define internal i64 @"VariadicPacks::sum_values.*\(\{ ptr, i64 \}' \
    "${variadic_llvm}"
  grep -Eq 'call i64 @"VariadicPacks::(forward_values|sum_values)' \
    "${variadic_llvm}"
  grep -Eq 'define internal i64 @"IndirectCalls::invoke_binary.*\(ptr noundef' \
    "${indirect_llvm}"
  grep -Eq 'call i64 %0\(i64 %1, i64 %2\)' "${indirect_llvm}"
done

kgen_path="${MOJO_IOS_UPSTREAM_ROOT}/bazel-bin/KGEN/tools/kgen/kgen"
[[ -x "${kgen_path}" ]]
kgen_ir="${build_root}/AggregateCallingConventions.kgen.mlir"
env -u MODULAR_HOME \
  XDG_DATA_HOME="${MOJO_IOS_COMPILER_STATE_ROOT}/data" \
  XDG_CACHE_HOME="${MOJO_IOS_COMPILER_STATE_ROOT}/cache" \
  MODULAR_CACHE_DIR="${MOJO_IOS_COMPILER_STATE_ROOT}/cache/mojo" \
  "${kgen_path}" -elaborate -S \
    -o "${kgen_ir}" \
    "${project_root}/tests/cpu-conformance/AggregateCallingConventions.mojo" \
    -I "${MOJO_IOS_STDLIB_PATH}" \
    -I "${MOJO_IOS_MAX_MOJO_PATH}" \
    --target-triple=arm64-apple-ios15.0 \
    --target-cpu=generic

register_signature="$(grep -m 1 'kgen.func .*transform_register' "${kgen_ir}")"
memory_signature="$(grep -m 1 'kgen.func .*transform_memory' "${kgen_ir}")"
[[ -n "${register_signature}" ]]
[[ -n "${memory_signature}" ]]
[[ "${register_signature}" != *memoryOnly* ]]
[[ "$(grep -o 'memoryOnly' <<<"${memory_signature}" | wc -l | tr -d ' ')" -eq 2 ]]
[[ "${memory_signature}" = *" owned)"* ]]

echo "CPU_CORE_LANGUAGE_LOWERING_PASS fixtures=${#fixtures[@]} optimizations=0,3 routed_families=${family_count} aggregate_conventions=register,memory-only"
