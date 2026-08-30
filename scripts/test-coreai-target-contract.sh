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

for target_triple in arm64-apple-ios27.0 arm64-apple-ios27.0-simulator; do
  target_variant="${target_triple//[^a-zA-Z0-9]/-}"
  for optimization_level in 0 3; do
    variant="${target_variant}-O${optimization_level}"
    "${compiler_command[@]}" build \
      "${project_root}/probes/CoreAITargetContractProbe.mojo" \
      -I "${stdlib_path}" \
      --emit object \
      --target-triple "${target_triple}" \
      --target-cpu apple-m1 \
      --disable-warnings \
      --optimization-level "${optimization_level}" \
      -o "${output_root}/CoreAITargetContractProbe-${variant}.o"

    "${compiler_command[@]}" build \
      "${project_root}/probes/CoreAIMatmulMatmulProbe.mojo" \
      -I "${stdlib_path}" \
      -I "${max_path}" \
      -I "${kernels_path}" \
      --emit object \
      --target-triple "${target_triple}" \
      --target-cpu apple-m1 \
      --disable-warnings \
      --optimization-level "${optimization_level}" \
      -o "${output_root}/CoreAIMatmulMatmulProbe-${variant}.o"

    nm -u "${output_root}/CoreAIMatmulMatmulProbe-${variant}.o" | \
      rg -Fq '_AsyncRT_CoreAI_enqueueMatmulMatmulF32_2x3x4x2'
    if nm -u "${output_root}/CoreAIMatmulMatmulProbe-${variant}.o" | \
      rg -q '__mojo_coreai_semantic_'; then
      echo "unlowered Core AI semantic operation escaped region formation" >&2
      exit 1
    fi
    if nm -u "${output_root}/CoreAIMatmulMatmulProbe-${variant}.o" | \
      rg -q 'Metal|MTL|air\.'; then
      echo "Core AI semantic operations incorrectly entered Metal lowering" >&2
      exit 1
    fi
  done
done

for negative_probe in CoreAIUnsupportedSingleOpProbe CoreAIUnsupportedShapeProbe; do
  diagnostic_path="${output_root}/${negative_probe}.diagnostic"
  if "${compiler_command[@]}" build \
    "${project_root}/probes/${negative_probe}.mojo" \
    -I "${stdlib_path}" \
    -I "${max_path}" \
    -I "${kernels_path}" \
    --emit object \
    --target-triple arm64-apple-ios27.0 \
    --target-cpu apple-m1 \
    --disable-warnings \
    --optimization-level 3 \
    -o "${output_root}/${negative_probe}.o" \
    >"${diagnostic_path}" 2>&1; then
    echo "unsupported Core AI program unexpectedly compiled: ${negative_probe}" >&2
    exit 1
  fi
  rg -Fq 'Core AI region formation:' "${diagnostic_path}"
done

echo "COREAI_TARGET_CONTRACT_PASS target=distinct graph=two-matmul O=0,3 negatives=named fallback=none"
