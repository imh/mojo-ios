#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xcframework_path="${project_root}/build/MojoIOSCore.xcframework"
derived_data_root="${project_root}/build/DerivedData"

test -d "${xcframework_path}"

cd "${project_root}"

xcodebuild \
  -scheme MojoIOS \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "${derived_data_root}/iphonesimulator" \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -scheme MojoIOS \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${derived_data_root}/iphoneos" \
  CODE_SIGNING_ALLOWED=NO \
  build
