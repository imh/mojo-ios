#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checkout_root="${project_root}/.work/modular"
expected_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"

test -x "${checkout_root}/bazelw"
test "$(git -C "${checkout_root}" rev-parse HEAD)" = "${expected_revision}"
"${project_root}/scripts/apply-upstream-patches.sh"

cd "${checkout_root}"
./bazelw build \
  --config=build-mojo \
  --jobs=4 \
  --remote_cache= \
  --remote_executor= \
  //KGEN/tools/mojo:mojo
