#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build/ReferenceApp"
archive_path="${build_root}/MojoIOSReferenceApp.xcarchive"
stable_developer_directory="${MOJO_IOS_STABLE_DEVELOPER_DIR:-$(xcode-select -p)}"
bundle_identifier="${MOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER:-com.ianhorn.mojoios.reference}"
skip_dependency_build="${MOJO_IOS_REFERENCE_SKIP_DEPENDENCY_BUILD:-0}"

: "${MOJO_IOS_DEVELOPMENT_TEAM:?Set MOJO_IOS_DEVELOPMENT_TEAM to the Apple development team identifier}"

test -d "${stable_developer_directory}"
case "${skip_dependency_build}" in
  0|1) ;;
  *)
    echo "MOJO_IOS_REFERENCE_SKIP_DEPENDENCY_BUILD must be 0 or 1" >&2
    exit 2
    ;;
esac
export DEVELOPER_DIR="${stable_developer_directory}"

xcodebuild -version
metal_component="$(xcodebuild -showComponent MetalToolchain -json)"
test "$(plutil -extract status raw - <<<"${metal_component}")" = "installed"
metal_search_path="$(plutil -extract toolchainSearchPath raw - <<<"${metal_component}")"
metal_compiler="${metal_search_path}/Metal.xctoolchain/usr/bin/metal"
test -x "${metal_compiler}"
"${metal_compiler}" --version

if [[ "${skip_dependency_build}" = 0 ]]; then
  "${project_root}/scripts/build-source-core-xcframework.sh"
  "${project_root}/scripts/test-metal-feasibility.sh"
fi
"${project_root}/scripts/build-reference-xcframework.sh"

cmake \
  -S "${project_root}/ReferenceApp" \
  -B "${build_root}" \
  -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DMOJO_IOS_DEVELOPMENT_TEAM="${MOJO_IOS_DEVELOPMENT_TEAM}" \
  -DMOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER="${bundle_identifier}"

case "${archive_path}" in
  "${project_root}/build/ReferenceApp/MojoIOSReferenceApp.xcarchive") ;;
  *)
    echo "refusing unexpected reference archive path: ${archive_path}" >&2
    exit 2
    ;;
esac
rm -rf -- "${archive_path}"

xcodebuild \
  -quiet \
  -project "${build_root}/MojoIOSReferenceApp.xcodeproj" \
  -scheme MojoIOSReferenceApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "${archive_path}" \
  -allowProvisioningUpdates \
  archive

test -d "${archive_path}"
app_path="${archive_path}/Products/Applications/MojoIOSReferenceApp.app"
test -d "${app_path}"
codesign --verify --deep --strict --verbose=2 "${app_path}"

echo "REFERENCE_ARCHIVE_BUILD_PASS archive=${archive_path} signed=yes cpu=yes metal=yes coreai=no"
