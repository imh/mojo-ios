#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_path="${project_root}/build/ReferenceApp/MojoIOSReferenceApp.xcarchive"
export_path="${project_root}/build/ReferenceApp/AppStoreExport"
export_options_path="${project_root}/config/distribution/AppStoreExportOptions.plist"
exported_app_path="${export_path}/MojoIOSReferenceApp.app"
audit_policy_path="${project_root}/config/distribution/app-store-app-audit-policy.json"
audit_report_path="${project_root}/build/distribution-evidence/app-store-app-audit.json"
stable_developer_directory="${MOJO_IOS_STABLE_DEVELOPER_DIR:-$(xcode-select -p)}"

test -d "${stable_developer_directory}"
test -d "${archive_path}"
test -f "${export_options_path}"
export DEVELOPER_DIR="${stable_developer_directory}"

case "${export_path}" in
  "${project_root}/build/ReferenceApp/AppStoreExport") ;;
  *)
    echo "refusing unexpected App Store export path: ${export_path}" >&2
    exit 2
    ;;
esac
rm -rf -- "${export_path}"

xcodebuild \
  -exportArchive \
  -archivePath "${archive_path}" \
  -exportPath "${export_path}" \
  -exportOptionsPlist "${export_options_path}" \
  -allowProvisioningUpdates

ipa_path="${export_path}/MojoIOSReferenceApp.ipa"
test -f "${ipa_path}"
rm -rf -- "${exported_app_path}"
temporary_payload="$(mktemp -d "${TMPDIR:-/tmp}/mojo-ios-app-store-export.XXXXXX")"
cleanup_temporary_payload() {
  rm -rf -- "${temporary_payload}"
}
trap cleanup_temporary_payload EXIT
ditto -x -k "${ipa_path}" "${temporary_payload}"
test -d "${temporary_payload}/Payload/MojoIOSReferenceApp.app"
ditto \
  "${temporary_payload}/Payload/MojoIOSReferenceApp.app" \
  "${exported_app_path}"

upstream_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"
python3 "${project_root}/scripts/audit-apple-distribution.py" \
  "${exported_app_path}" \
  --policy "${audit_policy_path}" \
  --output "${audit_report_path}" \
  --provenance "deployment_target=15.0" \
  --provenance "optimization_level=3" \
  --provenance "upstream_revision=${upstream_revision}"

get_task_allow="$(
  codesign -d --entitlements :- "${exported_app_path}" 2>/dev/null |
    plutil -extract get-task-allow raw -
)"
test "${get_task_allow}" = "false"

echo "APP_STORE_EXPORT_PASS ipa=${ipa_path} signed=distribution audited=yes"
