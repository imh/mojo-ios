#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${project_root}/.work/modular"
compiler_path="${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo"
stdlib_path="${upstream_root}/mojo/stdlib"
max_path="${upstream_root}/max/mojo"
kernels_path="${upstream_root}/max/kernels/src"
output_root="${project_root}/build/coreai-target-contract"
compiler_state_root="${project_root}/build/compiler-state/coreai"

test -x "${compiler_path}"
mkdir -p "${output_root}" "${compiler_state_root}/data" \
  "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

for target_triple in \
  arm64-apple-macosx15.0 \
  arm64-apple-ios26.0 \
  arm64-apple-ios27.0 \
  arm64-apple-ios27.0-simulator; do
  target_variant="${target_triple//[^a-zA-Z0-9]/-}"
  "${compiler_command[@]}" build \
    "${project_root}/probes/CoreAITargetContractProbe.mojo" \
    -I "${stdlib_path}" \
    --emit object \
    --target-triple "${target_triple}" \
    --target-cpu apple-m1 \
    --disable-warnings \
    --optimization-level 3 \
    -o "${output_root}/CoreAITargetContractProbe-${target_variant}.o"
done

for optimization_level in 0 3; do
  diagnostic_path="${output_root}/CoreAIMatmulMatmulProbe-ios27-O${optimization_level}.diagnostic"
  if "${compiler_command[@]}" build \
    "${project_root}/probes/CoreAIMatmulMatmulProbe.mojo" \
    -I "${stdlib_path}" \
    -I "${max_path}" \
    -I "${kernels_path}" \
    --emit object \
    --target-triple arm64-apple-ios27.0 \
    --target-cpu apple-m1 \
    --disable-warnings \
    --optimization-level "${optimization_level}" \
    -o "${output_root}/CoreAIMatmulMatmulProbe-ios27-O${optimization_level}.o" \
    >"${diagnostic_path}" 2>&1; then
    echo "Core AI graph unexpectedly compiled without a standard graph backend" >&2
    exit 1
  fi
  rg -Fq 'Core AI graph lowering is not implemented' "${diagnostic_path}"
  if rg -q 'LLVM ERROR|Please submit a bug report|Stack dump|__mojo_coreai_semantic_|AsyncRT_CoreAI_enqueue' \
    "${diagnostic_path}"; then
    echo "Core AI rejection used a crash or a removed fixed-graph ABI" >&2
    exit 1
  fi
done

if rg -n 'CoreAIRegionPass|__mojo_coreai_semantic_|AsyncRT_CoreAI_(execute|enqueue)Matmul' \
  "${upstream_root}/KGEN" "${upstream_root}/AsyncRT" "${upstream_root}/max"; then
  echo "removed fixed-graph Core AI compiler/runtime path is still present" >&2
  exit 1
fi

echo "COREAI_TARGET_CONTRACT_PASS target=distinct accelerator=false valid=false graph=not-implemented O=0,3 crash=none fallback=none"
