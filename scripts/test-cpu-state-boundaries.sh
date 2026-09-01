#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
compiler_path="${MOJO_IOS_MOJO_BINARY:-${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo}"
stdlib_path="${MOJO_IOS_STDLIB_PATH:-${upstream_root}/mojo/stdlib}"
max_mojo_path="${MOJO_IOS_MAX_MOJO_PATH:-${upstream_root}/max/mojo}"
build_root="${project_root}/build/cpu-state-boundaries"
compiler_state_root="${project_root}/build/compiler-state/cpu-state-boundaries"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_mojo_path}/max"
mkdir -p "${build_root}" "${compiler_state_root}/data" "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

expect_generic_failure() {
  local fixture_name="$1"
  local diagnostic_pattern="$2"
  local target_triple="$3"
  local optimization_level="$4"
  local target_name="${target_triple//[^a-zA-Z0-9]/-}"
  local diagnostic_path="${build_root}/${fixture_name}-${target_name}-o${optimization_level}.log"
  local object_path="${build_root}/${fixture_name}-${target_name}-o${optimization_level}.o"

  if "${compiler_command[@]}" build \
    "${project_root}/tests/cpu-conformance/compile-fail/${fixture_name}.mojo" \
    -I "${stdlib_path}" \
    -I "${max_mojo_path}" \
    --target-triple="${target_triple}" \
    --target-cpu=generic \
    --optimization-level="${optimization_level}" \
    --emit object \
    -o "${object_path}" >"${diagnostic_path}" 2>&1; then
    echo "${fixture_name} unexpectedly compiled for ${target_triple} O${optimization_level}" >&2
    exit 1
  fi
  grep -Fq "${diagnostic_pattern}" "${diagnostic_path}"
  if grep -Eq 'CompilationTarget\.is_ios|target\.is_ios|not supported on iOS' \
    "${diagnostic_path}"; then
    echo "${fixture_name} acquired an iOS-specific diagnostic" >&2
    exit 1
  fi
}

for optimization_level in 0 3; do
  for target_triple in \
    arm64-apple-macos14.0 \
    arm64-apple-ios15.0 \
    arm64-apple-ios15.0-simulator; do
    expect_generic_failure \
      MutableModuleGlobal \
      "global variables are not supported; move this into a function body or use 'comptime' to declare a constant" \
      "${target_triple}" \
      "${optimization_level}"
    expect_generic_failure \
      NontrivialGlobalConstant \
      "global_constant requires a type with trivial copy and destroy semantics" \
      "${target_triple}" \
      "${optimization_level}"
  done
done

if rg -n --glob '*.mojo' '(ThreadLocal|thread_local)' "${stdlib_path}/std"; then
  echo "the pinned standard library now appears to expose thread-local state; classify and test it" >&2
  exit 1
fi

echo "CPU_STATE_BOUNDARY_PASS mutable_globals=generic-rejection tls=absent-upstream-api targets=3 optimizations=0,3"
