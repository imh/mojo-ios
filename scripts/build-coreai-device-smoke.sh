#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_directory="${project_root}/build/CoreAIDeviceSmoke"
coreai_asset="${project_root}/build/coreai-mvp/CoreAIMatmulMatmulF32.aimodel"

: "${MOJO_IOS_COREAI_DEVELOPER_DIR:?Set MOJO_IOS_COREAI_DEVELOPER_DIR to the Xcode 27 Contents/Developer directory}"

test -d "${MOJO_IOS_COREAI_DEVELOPER_DIR}"
test -d "${coreai_asset}"
export DEVELOPER_DIR="${MOJO_IOS_COREAI_DEVELOPER_DIR}"

case "${build_directory}" in
  "${project_root}/build/CoreAIDeviceSmoke") ;;
  *) echo "refusing unexpected Core AI device build path" >&2; exit 2 ;;
esac
rm -rf -- "${build_directory}"

cmake_arguments=(
  -S "${project_root}/CoreAIDeviceSmoke"
  -B "${build_directory}"
  -G Xcode
  -DCMAKE_SYSTEM_NAME=iOS
  -DCMAKE_OSX_SYSROOT=iphoneos
  -DCMAKE_OSX_ARCHITECTURES=arm64
)
if [[ -n "${MOJO_IOS_DEVELOPMENT_TEAM:-}" ]]; then
  cmake_arguments+=(
    -DMOJO_IOS_DEVELOPMENT_TEAM="${MOJO_IOS_DEVELOPMENT_TEAM}"
  )
fi

cmake "${cmake_arguments[@]}"

build_arguments=(
  --build "${build_directory}"
  --config Debug
  --target MojoIOSCoreAIDeviceSmoke
  --
  -quiet
)
if [[ -n "${MOJO_IOS_DEVELOPMENT_TEAM:-}" ]]; then
  build_arguments+=(-allowProvisioningUpdates)
fi
cmake "${build_arguments[@]}"

app_bundle="${build_directory}/Debug-iphoneos/MojoIOSCoreAIDeviceSmoke.app"
test -d "${app_bundle}"
test -d "${app_bundle}/CoreAIMatmulMatmulF32.aimodel"
test -f "${app_bundle}/CoreAIMatmulMatmulF32.aimodel/metadata.json"
forbidden_app_file="$(
  find "${app_bundle}" -type f \
    \( -name '*.mojo' -o -name '*.py' -o -name '*.pyc' \
       -o -iname '*compiler*' -o -iname '*jit*' \) \
    -print -quit
)"
if [[ -n "${forbidden_app_file}" ]]; then
  echo "forbidden source/compiler/JIT content in app: ${forbidden_app_file}" >&2
  exit 1
fi
test ! -e "${app_bundle}/CoreAIDirectGraphProbe.aimodel"
linked_libraries="$(
  otool -L "${app_bundle}/MojoIOSCoreAIDeviceSmoke"
)"
rg -Fq "/System/Library/Frameworks/CoreAI.framework/CoreAI" \
  <<<"${linked_libraries}"

global_symbols="$(
  nm -g "${app_bundle}/MojoIOSCoreAIDeviceSmoke"
)"
if rg -q 'mojo_ios_coreai|MojoIOSCoreAI|AsyncRT_CoreAI' \
  <<<"${global_symbols}"; then
  echo "project-specific Mojo/Core AI ABI leaked into direct Apple probe" >&2
  exit 1
fi

echo "COREAI_DEVICE_APP_BUILD_PASS deployment=ios27 source=direct-swift-probe resource=aimodel mojo_backend=not-implemented fallback=none signed=$([[ -n "${MOJO_IOS_DEVELOPMENT_TEAM:-}" ]] && echo yes || echo no)"
