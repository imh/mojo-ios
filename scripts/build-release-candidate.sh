#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
source_xcframework="${MOJO_IOS_RELEASE_XCFRAMEWORK:-${project_root}/build/MojoIOSCore.xcframework}"
release_root="${project_root}/build/release-candidate"
staging_root="${release_root}/staging"
signed_xcframework="${staging_root}/MojoIOSCore.xcframework"
audit_report="${project_root}/build/distribution-evidence/release-candidate-audit.json"
audit_policy="${project_root}/config/distribution/release-candidate-audit-policy.json"
metadata="${project_root}/config/distribution/release-metadata.json"
upstream_root="${project_root}/.work/modular"
signing_identity="${MOJO_IOS_XCFRAMEWORK_SIGNING_IDENTITY:-}"
skip_build="${MOJO_IOS_RELEASE_SKIP_BUILD:-0}"
require_clean="${MOJO_IOS_REQUIRE_CLEAN_RELEASE:-1}"
release_version="$(
  python3 -c \
    'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' \
    "${metadata}"
)"
if [[ ! "${release_version}" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
  echo "release metadata version must be numeric semantic versioning" >&2
  exit 2
fi
release_bundle="${release_root}/MojoIOSCore-${release_version}-xcode27-preview"

case "${skip_build}" in
  0|1) ;;
  *)
    echo "MOJO_IOS_RELEASE_SKIP_BUILD must be 0 or 1" >&2
    exit 2
    ;;
esac
case "${require_clean}" in
  0|1) ;;
  *)
    echo "MOJO_IOS_REQUIRE_CLEAN_RELEASE must be 0 or 1" >&2
    exit 2
    ;;
esac
if [[ -z "${signing_identity}" ]]; then
  echo "MOJO_IOS_XCFRAMEWORK_SIGNING_IDENTITY is required" >&2
  exit 2
fi
if [[ "${developer_directory}" != "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
  echo "the current release-candidate policy requires Xcode 27 beta" >&2
  exit 2
fi
if [[ "${require_clean}" = 1 ]] && [[ -n "$(git -C "${project_root}" status --porcelain)" ]]; then
  echo "release provenance requires a clean project worktree" >&2
  exit 1
fi

export DEVELOPER_DIR="${developer_directory}"
xcode_version="$(xcodebuild -version)"
grep -Fxq "Xcode 27.0" <<<"${xcode_version}"
grep -Fxq "Build version 27A5252f" <<<"${xcode_version}"
metal_component="$(xcodebuild -showComponent MetalToolchain -json)"
test "$(plutil -extract status raw - <<<"${metal_component}")" = installed
metal_search_path="$(plutil -extract toolchainSearchPath raw - <<<"${metal_component}")"
metal_compiler="${metal_search_path}/Metal.xctoolchain/usr/bin/metal"
test -x "${metal_compiler}"
"${metal_compiler}" --version

if [[ "${skip_build}" = 0 ]]; then
  "${project_root}/scripts/build-source-core-xcframework.sh"
fi
test -d "${source_xcframework}"
test -f "${audit_policy}"
test -f "${metadata}"
test -d "${upstream_root}/.git"

case "${staging_root}" in
  "${project_root}/build/release-candidate/staging") ;;
  *)
    echo "refusing unexpected release staging path: ${staging_root}" >&2
    exit 2
    ;;
esac
case "${release_bundle}" in
  "${project_root}/build/release-candidate/MojoIOSCore-${release_version}-xcode27-preview") ;;
  *)
    echo "refusing unexpected release bundle path: ${release_bundle}" >&2
    exit 2
    ;;
esac
rm -rf -- "${staging_root}" "${release_bundle}"
mkdir -p "${staging_root}" "${release_bundle}" "$(dirname "${audit_report}")"
ditto "${source_xcframework}" "${signed_xcframework}"
codesign \
  --force \
  --timestamp \
  --sign "${signing_identity}" \
  "${signed_xcframework}"
codesign --verify --deep --strict --verbose=4 "${signed_xcframework}"

upstream_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"
python3 "${project_root}/scripts/audit-apple-distribution.py" \
  "${signed_xcframework}" \
  --policy "${audit_policy}" \
  --output "${audit_report}" \
  --provenance "deployment_target=15.0" \
  --provenance "optimization_level=3" \
  --provenance "upstream_revision=${upstream_revision}"

generator_arguments=(
  generate
  --xcframework "${signed_xcframework}"
  --audit-report "${audit_report}"
  --metadata "${metadata}"
  --output "${release_bundle}"
  --project-license "${project_root}/LICENSE"
  --source-date-epoch "$(git -C "${project_root}" show -s --format=%ct HEAD)"
  --upstream-revision "${project_root}/upstream/REVISION"
  --upstream-root "${upstream_root}"
)
if [[ "${require_clean}" = 1 ]]; then
  generator_arguments+=(--require-clean)
fi
python3 "${project_root}/scripts/release-provenance.py" \
  "${generator_arguments[@]}"

swift_checksum="$(
  swift package compute-checksum \
    "${release_bundle}/MojoIOSCore.xcframework.zip"
)"
recorded_checksum="$(
  awk '$2 == "MojoIOSCore.xcframework.zip" { print $1 }' \
    "${release_bundle}/SHA256SUMS"
)"
test -n "${recorded_checksum}"
test "${swift_checksum}" = "${recorded_checksum}"

echo \
  "RELEASE_CANDIDATE_BUILD_PASS bundle=${release_bundle} signed=yes sbom=spdx-2.3 notices=yes swift_checksum=${swift_checksum}"
