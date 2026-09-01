#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compiler_path="${MOJO_IOS_MOJO_BINARY:?set MOJO_IOS_MOJO_BINARY to the source-built compiler}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:?set MOJO_IOS_STDLIB_PATH to the patched stdlib source root}"
max_path="${MOJO_IOS_MAX_PATH:-${stdlib_path%/mojo/stdlib}/max/mojo}"
build_root="${project_root}/build/unsupported-target-probes"
compiler_state_root="${project_root}/build/compiler-state/target-policy"
compiler_data_root="${compiler_state_root}/data"
compiler_cache_root="${compiler_state_root}/cache"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_path}/max"
mkdir -p "${build_root}" "${compiler_data_root}" \
  "${compiler_cache_root}"

run_compile_fail_probe() {
  local probe_name="$1"
  local expected_operation="$2"
  local diagnostic_path="${build_root}/${probe_name}.diagnostic.txt"

  if env -u MODULAR_HOME \
      XDG_DATA_HOME="${compiler_data_root}" \
      XDG_CACHE_HOME="${compiler_cache_root}" \
      MODULAR_CACHE_DIR="${compiler_cache_root}/mojo" \
      "${compiler_path}" build \
      "${project_root}/probes/${probe_name}.mojo" \
      -I "${stdlib_path}" \
      -I "${max_path}" \
      --target-triple=arm64-apple-ios15.0 \
      --target-cpu=generic \
      --emit object \
      -o "${build_root}/${probe_name}.o" \
      >"${diagnostic_path}" 2>&1; then
    echo "${probe_name} unexpectedly compiled for iOS" >&2
    exit 1
  fi

  grep -Fq "${expected_operation}" "${diagnostic_path}"
  grep -Fq "iOS" "${diagnostic_path}"
}

run_compile_fail_probe UnsupportedDynamicLoadingProbe "dynamic library loading"
run_compile_fail_probe UnsupportedSubprocessProbe "std.subprocess.run"
run_compile_fail_probe UnsupportedPythonProbe "Python interoperability"
run_compile_fail_probe UnsupportedAsyncRTTimeTraceProbe \
  "MAX AsyncRT time tracing"

echo "verified four explicit iOS compile-time rejections"
