#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${project_root}/.work/modular"
compiler_path="${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo"
stdlib_path="${upstream_root}/mojo/stdlib"
max_path="${upstream_root}/max/mojo"
output_root="${project_root}/build/metal-argument-gate"
compiler_state_root="${project_root}/build/compiler-state/metal-arguments"
ir_output="${output_root}/captured-affine.ll"

mkdir -p "${output_root}" "${compiler_state_root}/data" \
  "${compiler_state_root}/cache"

MOJO_IOS_METAL_ARGUMENT_IR_OUTPUT="${ir_output}" \
  "${project_root}/scripts/test-metal-feasibility.sh"

rg -Fq 'load { ptr addrspace(1), ptr addrspace(1) }' "${ir_output}"
rg -Fq '!"air.buffer_size", i32 16' "${ir_output}"
rg -Fq '!"air.arg_type_align_size", i32 16' "${ir_output}"
rg -Fq '!"air.buffer_size", i32 12' "${ir_output}"
test "$(rg -c '!"air.read"' "${ir_output}")" -ge 4
rg -Fq '!"air.write"' "${ir_output}"
rg -Fq '!"air.read_write"' "${ir_output}"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

expect_rejection() {
  local probe_name="$1"
  local expected_diagnostic="$2"
  local target_triple="$3"
  local target_arch="$4"
  local diagnostic_path="${output_root}/${probe_name}-${target_triple}.txt"

  if "${compiler_command[@]}" build \
    "${project_root}/probes/${probe_name}.mojo" \
    -I "${stdlib_path}" \
    -I "${max_path}" \
    --emit object \
    --target-triple "${target_triple}" \
    --target-cpu "${target_arch}" \
    --target-accelerator "${target_arch}" \
    --optimization-level 3 \
    -o "${output_root}/${probe_name}-${target_triple}.o" \
    >"${diagnostic_path}" 2>&1; then
    echo "${probe_name} unexpectedly compiled for ${target_triple}" >&2
    exit 1
  fi
  rg -Fq "${expected_diagnostic}" "${diagnostic_path}"
}

for target_specification in \
  'arm64-apple-macosx15.0 apple-m1' \
  'arm64-apple-ios15.0 apple-m1'; do
  read -r target_triple target_arch <<<"${target_specification}"
  expect_rejection \
    IOSMetalUnsupportedTupleProbe \
    "does not conform to trait 'DevicePassable'" \
    "${target_triple}" "${target_arch}"
  expect_rejection \
    IOSMetalUnsupportedNestedGenericPointerProbe \
    'nested device pointers must use AddressSpace.GLOBAL' \
    "${target_triple}" "${target_arch}"
done

echo "verified explicit Metal argument types, layouts, access metadata, and named unsupported boundaries"
