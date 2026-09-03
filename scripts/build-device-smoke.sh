#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"

device_smoke_build_directory="${project_root}/build/DeviceSmoke"
enable_metal_smoke="${MOJO_IOS_ENABLE_METAL_SMOKE:-OFF}"

: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set MOJO_IOS_DEVELOPMENT_TEAM to the Apple development team identifier}"

case "${enable_metal_smoke}" in
  ON|OFF) ;;
  *)
    echo "MOJO_IOS_ENABLE_METAL_SMOKE must be ON or OFF" >&2
    exit 2
    ;;
esac

mojo_ios_select_apple_toolchain

cmake \
  -S "${project_root}/DeviceSmoke" \
  -B "${device_smoke_build_directory}" \
  -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DMOJO_IOS_ENABLE_METAL_SMOKE="${enable_metal_smoke}" \
  -DMOJO_IOS_DEVELOPMENT_TEAM="${MOJO_IOS_DEVELOPMENT_TEAM}"

cmake \
  --build "${device_smoke_build_directory}" \
  --config Debug \
  --target MojoIOSDeviceSmoke \
  -- -allowProvisioningUpdates

test -d "${device_smoke_build_directory}/Debug-iphoneos/MojoIOSDeviceSmoke.app"
