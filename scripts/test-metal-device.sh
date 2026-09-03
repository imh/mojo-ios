#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"

: "${MOJO_IOS_CORE_DEVICE_ID:?Set MOJO_IOS_CORE_DEVICE_ID to the CoreDevice identifier}"
: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set MOJO_IOS_DEVELOPMENT_TEAM to the Apple development team identifier}"

mojo_ios_select_apple_toolchain

"${project_root}/scripts/test-metal-feasibility.sh"

MOJO_IOS_ENABLE_METAL_SMOKE=ON \
  "${project_root}/scripts/test-swift-device.sh"

"${project_root}/scripts/record-gate-evidence.py" \
  --gate metal-device \
  --result pass \
  --output "${project_root}/build/evidence/metal-device.json" \
  --field "optimization_level=${MOJO_IOS_METAL_OPTIMIZATION_LEVEL:-3}" \
  --field "debug_level=${MOJO_IOS_METAL_DEBUG_LEVEL:-none}" \
  --field "device_id=${MOJO_IOS_CORE_DEVICE_ID}" \
  --artifact "${project_root}/build/metal-gate/IOSMetalVectorAddProbe.o" \
  --artifact "${project_root}/build/DeviceSmoke/Debug-iphoneos/MojoIOSDeviceSmoke.app/MojoIOSDeviceSmoke"
