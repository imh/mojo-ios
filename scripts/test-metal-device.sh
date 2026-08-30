#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${MOJO_IOS_CORE_DEVICE_ID:?Set MOJO_IOS_CORE_DEVICE_ID to the CoreDevice identifier}"
: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set MOJO_IOS_DEVELOPMENT_TEAM to the Apple development team identifier}"

"${project_root}/scripts/test-metal-feasibility.sh"

MOJO_IOS_ENABLE_METAL_SMOKE=ON \
  "${project_root}/scripts/test-swift-device.sh"
