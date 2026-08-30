#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checkout_root="${project_root}/.work/modular"
compiler_path="${checkout_root}/bazel-bin/KGEN/tools/mojo/mojo"
stdlib_path="${checkout_root}/mojo/stdlib"
max_path="${checkout_root}/max/mojo"
probe_path="${project_root}/probes/MaxAlgorithmParallelizeProbe.mojo"
output_root="${project_root}/build/probes/max-algorithm-parallelize"
expected_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_path}/max"
test -f "${probe_path}"
test "$(git -C "${checkout_root}" rev-parse HEAD)" = "${expected_revision}"
"${project_root}/scripts/apply-upstream-patches.sh"
mkdir -p \
  "${output_root}" \
  "${project_root}/build/compiler-state/data" \
  "${project_root}/build/compiler-state/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${project_root}/build/compiler-state/data"
  XDG_CACHE_HOME="${project_root}/build/compiler-state/cache"
  MODULAR_CACHE_DIR="${project_root}/build/compiler-state/cache/mojo"
  "${compiler_path}"
)

compile_variant() {
  local variant_name="$1"
  local target_triple="$2"
  local optimization_level="$3"
  local debug_level="none"
  if [[ "${optimization_level}" = "0" ]]; then
    debug_level="full"
  fi

  "${compiler_command[@]}" build "${probe_path}" \
    -I "${stdlib_path}" \
    -I "${max_path}" \
    --target-triple="${target_triple}" \
    --target-cpu=generic \
    --optimization-level="${optimization_level}" \
    --debug-level="${debug_level}" \
    --emit object \
    -o "${output_root}/${variant_name}-o${optimization_level}.o"
}

for optimization_level in 0 3; do
  compile_variant iphoneos arm64-apple-ios15.0 "${optimization_level}"
  compile_variant iphonesimulator arm64-apple-ios15.0-simulator \
    "${optimization_level}"
done

for object_path in "${output_root}"/*.o; do
  for symbol_name in \
    AsyncRT_DeviceContext_create \
    AsyncRT_DeviceContext_deviceApi \
    AsyncRT_DeviceContext_enqueueHostFunctionRange \
    AsyncRT_DeviceContext_release \
    AsyncRT_DeviceContext_strfree \
    AsyncRT_DeviceContext_synchronize \
    KGEN_CompilerRT_AsyncRT_ParallelismLevel; do
    nm -u "${object_path}" | rg -q "_${symbol_name}$"
  done
  if nm -u "${object_path}" | rg -q '_mojo_ios_runtime_parallel_for'; then
    echo "legacy iOS parallel bridge leaked into ${object_path}" >&2
    exit 1
  fi
done

for object_path in "${output_root}"/*-o0.o; do
  nm -u "${object_path}" | rg -q '_AsyncRT_DeviceContext_getAttribute$'
  nm -u "${object_path}" | rg -q '_AsyncRT_DeviceContext_retain$'
done

echo "verified unmodified max.algorithm.parallelize lowering for iOS device and simulator at O0/O3"
