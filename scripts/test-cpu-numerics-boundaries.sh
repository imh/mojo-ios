#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
build_root="${project_root}/build/cpu-numerics-boundaries"
compiler_state_root="${project_root}/build/compiler-state/cpu-numerics-boundaries"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
mkdir -p "${build_root}" "${compiler_state_root}/data" "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

triples=(
  arm64-apple-macos14.0
  arm64-apple-ios15.0
  arm64-apple-ios15.0-simulator
)
expected_diagnostic='SIMD vector length must be a power of two'
reference_diagnostic=""

for target_triple in "${triples[@]}"; do
  for optimization_level in 0 3; do
    log_path="${build_root}/${target_triple}-o${optimization_level}.log"
    if "${compiler_command[@]}" build \
      "${project_root}/tests/cpu-conformance/compile-fail/OddWidthSIMD.mojo" \
      -I "${stdlib_path}" \
      --target-triple="${target_triple}" \
      --target-cpu=generic \
      --optimization-level="${optimization_level}" \
      --emit object \
      -o "${build_root}/${target_triple}-o${optimization_level}.o" \
      >"${log_path}" 2>&1; then
      echo "odd-width SIMD unexpectedly compiled for ${target_triple} O${optimization_level}" >&2
      exit 1
    fi
    diagnostic="$(grep -F -m1 "${expected_diagnostic}" "${log_path}")"
    test -n "${diagnostic}"
    diagnostic="${diagnostic#*: error: }"
    if [[ -z "${reference_diagnostic}" ]]; then
      reference_diagnostic="${diagnostic}"
    else
      test "${diagnostic}" = "${reference_diagnostic}"
    fi
  done
done

echo "CPU_NUMERICS_BOUNDARY_PASS odd_width=generic-rejection targets=3 optimizations=0,3"
