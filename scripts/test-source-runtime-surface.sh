#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${project_root}/scripts/apply-upstream-patches.sh"

MOJO_IOS_MOJO_BINARY="${project_root}/.work/modular/bazel-bin/KGEN/tools/mojo/mojo" \
MOJO_IOS_STDLIB_PATH="${project_root}/.work/modular/mojo/stdlib" \
MOJO_IOS_UPSTREAM_ROOT="${project_root}/.work/modular" \
  "${project_root}/scripts/test-supported-runtime-surface.sh"
