#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_path="${project_root}/build/ReferenceApp/MojoIOSReferenceApp.xcarchive"
export_path="${project_root}/build/ReferenceApp/AppStoreValidation"
result_bundle_path="${project_root}/build/ReferenceApp/AppStoreValidation.xcresult"
export_options_path="${project_root}/config/distribution/AppStoreValidationExportOptions.plist"
stable_developer_directory="${MOJO_IOS_STABLE_DEVELOPER_DIR:-$(xcode-select -p)}"

test -d "${stable_developer_directory}"
test -d "${archive_path}"
test -f "${export_options_path}"
export DEVELOPER_DIR="${stable_developer_directory}"

case "${export_path}" in
  "${project_root}/build/ReferenceApp/AppStoreValidation") ;;
  *)
    echo "refusing unexpected validation export path: ${export_path}" >&2
    exit 2
    ;;
esac
case "${result_bundle_path}" in
  "${project_root}/build/ReferenceApp/AppStoreValidation.xcresult") ;;
  *)
    echo "refusing unexpected validation result path: ${result_bundle_path}" >&2
    exit 2
    ;;
esac
rm -rf -- "${export_path}" "${result_bundle_path}"

xcodebuild \
  -exportArchive \
  -archivePath "${archive_path}" \
  -exportPath "${export_path}" \
  -exportOptionsPlist "${export_options_path}" \
  -allowProvisioningUpdates \
  -resultBundlePath "${result_bundle_path}"

echo "APP_STORE_VALIDATION_PASS archive=${archive_path} result=${result_bundle_path}"
