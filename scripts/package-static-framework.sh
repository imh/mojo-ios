#!/bin/bash
set -euo pipefail

if [[ "$#" != 3 ]]; then
  echo "usage: package-static-framework.sh ARCHIVE OUTPUT_FRAMEWORK MINIMUM_OS" >&2
  exit 2
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_path="$1"
framework_path="$2"
minimum_os="$3"
framework_name="MojoIOSCore"
framework_binary="${framework_path}/${framework_name}"
info_template="${project_root}/config/distribution/StaticFrameworkInfo.plist"
privacy_manifest="${project_root}/config/distribution/SDKPrivacyInfo.xcprivacy"

test -f "${archive_path}"
test -f "${info_template}"
test -f "${privacy_manifest}"
test -f "${project_root}/include/MojoIOSCore.h"
test -f "${project_root}/include/framework.modulemap"

case "${framework_path}" in
  "${project_root}/build/"*.framework) ;;
  *)
    echo "refusing unexpected static framework path: ${framework_path}" >&2
    exit 2
    ;;
esac

rm -rf -- "${framework_path}"
mkdir -p "${framework_path}/Headers" "${framework_path}/Modules"
cp "${archive_path}" "${framework_binary}"
cp "${project_root}/include/MojoIOSCore.h" "${framework_path}/Headers/"
cp "${project_root}/include/framework.modulemap" \
  "${framework_path}/Modules/module.modulemap"
cp "${info_template}" "${framework_path}/Info.plist"
cp "${privacy_manifest}" "${framework_path}/PrivacyInfo.xcprivacy"
plutil -replace MinimumOSVersion -string "${minimum_os}" \
  "${framework_path}/Info.plist"

case "$(file -b "${framework_binary}")" in
  "current ar archive"*) ;;
  *)
    echo "static framework binary is not an archive: ${framework_binary}" >&2
    exit 1
    ;;
esac
plutil -lint "${framework_path}/Info.plist" "${framework_path}/PrivacyInfo.xcprivacy"

echo "STATIC_FRAMEWORK_PACKAGE_PASS framework=${framework_path} privacy=yes"
