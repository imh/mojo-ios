#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compiler_path="${MOJO_IOS_MOJO_BINARY:?set MOJO_IOS_MOJO_BINARY to the source-built compiler}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:?set MOJO_IOS_STDLIB_PATH to the patched stdlib source root}"
build_root="${project_root}/build/probes/language-async"
compiler_state_root="${project_root}/build/compiler-state/language-async"
compiler_data_root="${compiler_state_root}/data"
compiler_cache_root="${compiler_state_root}/cache"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
mkdir -p "${build_root}" "${compiler_data_root}" "${compiler_cache_root}"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_data_root}"
  XDG_CACHE_HOME="${compiler_cache_root}"
  MODULAR_CACHE_DIR="${compiler_cache_root}/mojo"
  "${compiler_path}"
)

compile_probe() {
  local probe_name="$1"
  local variant_name="$2"
  local target_triple="$3"
  local optimization_level="$4"
  local debug_level="none"
  local object_path="${build_root}/${probe_name}-${variant_name}-o${optimization_level}.o"

  if [[ "${optimization_level}" = "0" ]]; then
    debug_level="full"
  fi

  "${compiler_command[@]}" build \
    "${project_root}/probes/${probe_name}.mojo" \
    -I "${stdlib_path}" \
    --target-triple="${target_triple}" \
    --target-cpu=generic \
    --optimization-level="${optimization_level}" \
    --debug-level="${debug_level}" \
    --emit object \
    -o "${object_path}"

  for runtime_symbol in \
    KGEN_CompilerRT_AsyncRT_Complete \
    KGEN_CompilerRT_AsyncRT_DestroyChain \
    KGEN_CompilerRT_AsyncRT_Execute \
    KGEN_CompilerRT_AsyncRT_InitializeChain \
    KGEN_CompilerRT_AsyncRT_Wait; do
    nm -u "${object_path}" | rg -q "_${runtime_symbol}$"
  done

  if [[ "${probe_name}" = "LanguageAsyncAwaitProbe" ]]; then
    nm -u "${object_path}" | \
      rg -q '_KGEN_CompilerRT_AsyncRT_AndThen$'
  fi

  if nm -u "${object_path}" | rg -q '_mojo_ios_.*async.*runtime'; then
    echo "project-specific async runtime symbol leaked into ${object_path}" >&2
    exit 1
  fi
}

for optimization_level in 0 3; do
  for probe_name in \
    LanguageAsyncResultProbe \
    LanguageAsyncAwaitProbe \
    LanguageAsyncRaisingProbe; do
    compile_probe \
      "${probe_name}" iphoneos arm64-apple-ios15.0 \
      "${optimization_level}"
    compile_probe \
      "${probe_name}" iphonesimulator arm64-apple-ios15.0-simulator \
      "${optimization_level}"
  done
done

echo "verified ordinary async, await, results, and raised errors use the generic AsyncRT ABI for iOS device and simulator at O0/O3"
