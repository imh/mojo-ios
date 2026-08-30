#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${project_root}/.work/modular"

"${project_root}/scripts/apply-upstream-patches.sh"

cd "${upstream_root}"
./bazelw build \
  --config=prebuilt-mojo \
  --remote_cache= \
  --remote_downloader= \
  //KGEN:CompilerRTEmbeddedApple \
  //AsyncRT:DeviceContextCAPIApple
