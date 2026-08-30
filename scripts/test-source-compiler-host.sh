#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checkout_root="${project_root}/.work/modular"
compiler_path="${checkout_root}/bazel-bin/KGEN/tools/mojo/mojo"
compiler_runtime_path="${checkout_root}/bazel-bin/KGEN/libKGENCompilerRTShared.dylib"
stdlib_path="${checkout_root}/mojo/stdlib"
executable_path="${project_root}/build/source-compiler-host-smoke"
compiler_state_root="${project_root}/build/compiler-state/source-host"
compiler_data_root="${compiler_state_root}/data"
compiler_cache_root="${compiler_state_root}/cache"
expected_marker="MOJO_IOS_SOURCE_COMPILER_HOST_PASS result=42"

test -x "${compiler_path}"
test -f "${compiler_runtime_path}"
test -d "${stdlib_path}/std"
mkdir -p "${project_root}/build" "${compiler_data_root}" \
  "${compiler_cache_root}"

env -u MODULAR_HOME \
  XDG_DATA_HOME="${compiler_data_root}" \
  XDG_CACHE_HOME="${compiler_cache_root}" \
  MODULAR_CACHE_DIR="${compiler_cache_root}/mojo" \
  MODULAR_MOJO_MAX_COMPILERRT_PATH="${compiler_runtime_path}" \
  "${compiler_path}" build \
  "${project_root}/probes/SourceCompilerHostSmoke.mojo" \
  -I "${stdlib_path}" \
  -o "${executable_path}"

smoke_output="$(
  DYLD_LIBRARY_PATH="${checkout_root}/bazel-bin/KGEN" "${executable_path}"
)"
printf '%s\n' "${smoke_output}"
grep -Fq "${expected_marker}" <<<"${smoke_output}"
