#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_path="${project_root}/build/ReferenceApp/MojoIOSReferenceApp.xcarchive"
export_path="${project_root}/build/ReferenceApp/AppStoreValidation"
validation_log_path="${project_root}/build/ReferenceApp/AppStoreValidation.log"
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
case "${validation_log_path}" in
  "${project_root}/build/ReferenceApp/AppStoreValidation.log") ;;
  *)
    echo "refusing unexpected validation log path: ${validation_log_path}" >&2
    exit 2
    ;;
esac
rm -rf -- "${export_path}"
rm -f -- "${validation_log_path}"

xcodebuild \
  -exportArchive \
  -archivePath "${archive_path}" \
  -exportPath "${export_path}" \
  -exportOptionsPlist "${export_options_path}" \
  -allowProvisioningUpdates \
  2>&1 | tee "${validation_log_path}"

test -f "${validation_log_path}"
grep -Fq "Validated MojoIOSReferenceApp" "${validation_log_path}"
grep -Fq "** EXPORT SUCCEEDED **" "${validation_log_path}"

echo "APP_STORE_VALIDATION_PASS archive=${archive_path} result=${validation_log_path}"
