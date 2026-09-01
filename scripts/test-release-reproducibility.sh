#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
reproducibility_root="${project_root}/build/reproducibility"
first_root="${reproducibility_root}/first"
second_root="${reproducibility_root}/second"
first_xcframework="${first_root}/MojoIOSCore.xcframework"
second_xcframework="${second_root}/MojoIOSCore.xcframework"
signing_identity="${MOJO_IOS_XCFRAMEWORK_SIGNING_IDENTITY:-}"
require_clean="${MOJO_IOS_REQUIRE_CLEAN_RELEASE:-1}"

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
  echo "the current reproducibility policy requires Xcode 27 beta" >&2
  exit 2
fi
if [[ "${require_clean}" = 1 ]] && [[ -n "$(git -C "${project_root}" status --porcelain)" ]]; then
  echo "release reproducibility requires a clean project worktree" >&2
  exit 1
fi

case "${reproducibility_root}" in
  "${project_root}/build/reproducibility") ;;
  *)
    echo "refusing unexpected reproducibility root: ${reproducibility_root}" >&2
    exit 2
    ;;
esac
rm -rf -- "${first_root}" "${second_root}"
mkdir -p "${first_root}" "${second_root}"

export DEVELOPER_DIR="${developer_directory}"
for build_root in "${first_root}" "${second_root}"; do
  MOJO_IOS_BUILD_ROOT="${build_root}" \
    "${project_root}/scripts/build-source-core-xcframework.sh"
done

diff -qr "${first_xcframework}" "${second_xcframework}"
first_unsigned_tree_sha256="$({
  cd "${first_xcframework}"
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256
} | shasum -a 256 | awk '{ print $1 }')"
second_unsigned_tree_sha256="$({
  cd "${second_xcframework}"
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256
} | shasum -a 256 | awk '{ print $1 }')"
test "${first_unsigned_tree_sha256}" = "${second_unsigned_tree_sha256}"

upstream_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"
for build_root in "${first_root}" "${second_root}"; do
  python3 "${project_root}/scripts/audit-apple-distribution.py" \
    "${build_root}/MojoIOSCore.xcframework" \
    --policy "${project_root}/config/distribution/current-xcframework-audit-policy.json" \
    --output "${build_root}/unsigned-audit.json" \
    --provenance "deployment_target=15.0" \
    --provenance "optimization_level=3" \
    --provenance "upstream_revision=${upstream_revision}"
done
cmp "${first_root}/unsigned-audit.json" "${second_root}/unsigned-audit.json"

for xcframework in "${first_xcframework}" "${second_xcframework}"; do
  codesign \
    --force \
    --timestamp \
    --sign "${signing_identity}" \
    "${xcframework}"
  codesign --verify --deep --strict --verbose=4 "${xcframework}"
done

full_code_directory_hash() {
  codesign -d --verbose=4 "$1" 2>&1 \
    | awk -F= '/^CandidateCDHashFull sha256=/ { print $2 }'
}
first_code_directory_sha256="$(full_code_directory_hash "${first_xcframework}")"
second_code_directory_sha256="$(full_code_directory_hash "${second_xcframework}")"
test -n "${first_code_directory_sha256}"
test "${first_code_directory_sha256}" = "${second_code_directory_sha256}"

for build_root in "${first_root}" "${second_root}"; do
  python3 "${project_root}/scripts/audit-apple-distribution.py" \
    "${build_root}/MojoIOSCore.xcframework" \
    --policy "${project_root}/config/distribution/release-candidate-audit-policy.json" \
    --output "${build_root}/signed-audit.json" \
    --provenance "deployment_target=15.0" \
    --provenance "optimization_level=3" \
    --provenance "upstream_revision=${upstream_revision}"
done

if [[ "${require_clean}" = 1 ]]; then
  result_name="RELEASE_REPRODUCIBILITY_PASS"
else
  result_name="RELEASE_REPRODUCIBILITY_DEVELOPMENT_PASS"
fi
echo \
  "${result_name} unsigned_tree_sha256=${first_unsigned_tree_sha256} signed_code_directory_sha256=${first_code_directory_sha256} cms_timestamp=excluded clean_required=${require_clean}"
