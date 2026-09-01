#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
max_mojo_path="${MOJO_IOS_MAX_MOJO_PATH:-${upstream_root}/max/mojo}"
build_root="${project_root}/build/cpu-numerics-lowering"
compiler_state_root="${project_root}/build/compiler-state/cpu-numerics-lowering"
expected_symbols="${project_root}/config/cpu-numeric-external-symbols.tsv"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_mojo_path}/max"
test -f "${expected_symbols}"
mkdir -p "${build_root}" "${compiler_state_root}/data" "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)
fixtures=(
  SIMDPrimitives
  BitIntrinsics
  StrictMath
  VectorizedMemory
  OptimizationSemantics
)

for optimization_level in 0 3; do
  for fixture_name in "${fixtures[@]}"; do
    source_path="${project_root}/tests/cpu-conformance/${fixture_name}.mojo"
    llvm_path="${build_root}/${fixture_name}-o${optimization_level}.ll"
    object_path="${build_root}/${fixture_name}-o${optimization_level}.o"
    "${compiler_command[@]}" build \
      "${source_path}" \
      -I "${stdlib_path}" \
      -I "${max_mojo_path}" \
      --target-triple=arm64-apple-ios15.0 \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --emit llvm \
      -o "${llvm_path}"
    "${compiler_command[@]}" build \
      "${source_path}" \
      -I "${stdlib_path}" \
      -I "${max_mojo_path}" \
      --target-triple=arm64-apple-ios15.0 \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --emit object \
      -o "${object_path}"
    grep -Fq 'target triple = "arm64-apple-ios15.0"' "${llvm_path}"
    if nm -u "${object_path}" | grep -Eq '___atomic_|___aeabi_|___gnu_'; then
      echo "${fixture_name} unexpectedly requires an emulation helper at O${optimization_level}" >&2
      exit 1
    fi
  done
done

strict_llvm="${build_root}/OptimizationSemantics-strict-o3.ll"
"${compiler_command[@]}" build \
  "${project_root}/tests/cpu-conformance/OptimizationSemantics.mojo" \
  -I "${stdlib_path}" \
  -I "${max_mojo_path}" \
  --target-triple=arm64-apple-ios15.0 \
  --target-cpu=generic \
  --optimization-level=3 \
  --fp-mode=contract=off \
  --emit llvm \
  -o "${strict_llvm}"

for optimization_level in 0 3; do
  simd_llvm="${build_root}/SIMDPrimitives-o${optimization_level}.ll"
  bit_llvm="${build_root}/BitIntrinsics-o${optimization_level}.ll"
  math_llvm="${build_root}/StrictMath-o${optimization_level}.ll"
  vector_llvm="${build_root}/VectorizedMemory-o${optimization_level}.ll"
  optimization_llvm="${build_root}/OptimizationSemantics-o${optimization_level}.ll"

  grep -Eq 'add <16 x i8>' "${simd_llvm}"
  grep -Eq 'mul <8 x i16>' "${simd_llvm}"
  grep -Eq '<8 x i32>' "${simd_llvm}"
  grep -Eq '<8 x half>' "${simd_llvm}"
  grep -Eq '<8 x bfloat>' "${simd_llvm}"
  grep -Eq 'shufflevector <4 x i32>' "${simd_llvm}"
  grep -Eq 'sext <4 x i8> .* to <4 x i16>' "${simd_llvm}"
  grep -Eq 'zext <4 x i8> .* to <4 x i16>' "${simd_llvm}"

  grep -Fq '@llvm.ctlz.i64' "${bit_llvm}"
  grep -Fq '@llvm.cttz.v8i16' "${bit_llvm}"
  grep -Fq '@llvm.ctpop.v16i8' "${bit_llvm}"
  grep -Fq '@llvm.bswap.v4i32' "${bit_llvm}"
  grep -Fq '@llvm.bitreverse.v2i64' "${bit_llvm}"

  grep -Fq '@llvm.sin.v4f32' "${math_llvm}"
  grep -Fq '@llvm.fma.f64' "${math_llvm}"

  grep -Fq '@llvm.masked.load.v4f32' "${vector_llvm}"
  grep -Fq '@llvm.masked.store.v4f32' "${vector_llvm}"
  grep -Eq 'icmp slt <4 x i32> .*splat \(i32 3\)' "${vector_llvm}"
  grep -Eq 'ptr align 1' "${vector_llvm}"
  grep -Eq 'load <4 x float>, ptr .*align 4' "${vector_llvm}"
  grep -Eq 'store <4 x float> .*ptr .*align 4' "${vector_llvm}"

  grep -Eq 'fadd contract float' "${optimization_llvm}"
  grep -Eq 'call contract float @llvm\.fma\.f32' "${optimization_llvm}"
  grep -Eq 'call fast float @llvm\.fma\.f32' "${optimization_llvm}"
done

strict_add_body="${build_root}/strict-add.ll"
strict_div_body="${build_root}/strict-div.ll"
wrapping_add_body="${build_root}/wrapping-add.ll"
awk '/define .*@mojo_ios_numeric_strict_add/{copy=1} copy{print} copy && /^}/{exit}' \
  "${strict_llvm}" >"${strict_add_body}"
awk '/define .*@mojo_ios_numeric_strict_div/{copy=1} copy{print} copy && /^}/{exit}' \
  "${strict_llvm}" >"${strict_div_body}"
awk '/define .*@mojo_ios_numeric_wrapping_add/{copy=1} copy{print} copy && /^}/{exit}' \
  "${strict_llvm}" >"${wrapping_add_body}"
grep -Eq 'fadd float' "${strict_add_body}"
grep -Eq 'fdiv float' "${strict_div_body}"
grep -Eq 'add i8' "${wrapping_add_body}"
if grep -Eq 'add (nuw|nsw)' "${wrapping_add_body}"; then
  echo "wrapping integer addition incorrectly retained no-wrap flags" >&2
  exit 1
fi
if grep -Eq ' (fast|contract|reassoc|nnan|ninf|nsz|arcp|afn) ' \
  "${strict_add_body}" "${strict_div_body}"; then
  echo "strict numeric helpers retained a fast-math flag with contraction disabled" >&2
  exit 1
fi

actual_pairs="${build_root}/external-symbol-pairs.tsv"
: >"${actual_pairs}"
for optimization_level in 0 3; do
  for fixture_name in "${fixtures[@]}"; do
    nm -u "${build_root}/${fixture_name}-o${optimization_level}.o" |
      awk -v fixture="${fixture_name}" \
        '$NF !~ /^_KGEN_CompilerRT_/ && $NF !~ /^_AsyncRT_/ {print fixture "\t" $NF}' \
        >>"${actual_pairs}"
  done
done
LC_ALL=C sort -u -o "${actual_pairs}" "${actual_pairs}"
expected_pairs="${build_root}/expected-external-symbol-pairs.tsv"
tail -n +2 "${expected_symbols}" | cut -f1-2 | LC_ALL=C sort -u >"${expected_pairs}"
diff -u "${expected_pairs}" "${actual_pairs}"
cp "${expected_symbols}" "${build_root}/numeric-external-symbols.tsv"

echo "CPU_NUMERICS_LOWERING_PASS fixtures=5 optimizations=0,3 strict_fp=yes external_symbols=attributed"
