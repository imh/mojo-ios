#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compiler_path="${project_root}/.work/modular/bazel-bin/KGEN/tools/mojo/mojo"
stdlib_path="${project_root}/.work/modular/mojo/stdlib"
max_path="${project_root}/.work/modular/max/mojo"
expected_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"

test -x "${compiler_path}"
test -d "${stdlib_path}/std"
test -d "${max_path}/max"
test "$(git -C "${project_root}/.work/modular" rev-parse HEAD)" = "${expected_revision}"

"${project_root}/scripts/apply-upstream-patches.sh"

MOJO_IOS_MOJO_BINARY="${compiler_path}" \
MOJO_IOS_STDLIB_PATH="${stdlib_path}" \
MOJO_IOS_MAX_PATH="${max_path}" \
MOJO_IOS_UPSTREAM_ROOT="${project_root}/.work/modular" \
  "${project_root}/scripts/build-core-xcframework.sh"
