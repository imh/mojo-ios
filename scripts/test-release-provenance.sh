#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_root="${project_root}/build/release-candidate"
signed_xcframework="${release_root}/staging/MojoIOSCore.xcframework"
audit_report="${project_root}/build/distribution-evidence/release-candidate-audit.json"
audit_policy="${project_root}/config/distribution/release-candidate-audit-policy.json"
metadata="${project_root}/config/distribution/release-metadata.json"
skip_build="${MOJO_IOS_RELEASE_PROVENANCE_SKIP_BUILD:-0}"
release_version="$(
  python3 -c \
    'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' \
    "${metadata}"
)"
bundle="${release_root}/MojoIOSCore-${release_version}-xcode27-preview"

case "${skip_build}" in
  0|1) ;;
  *)
    echo "MOJO_IOS_RELEASE_PROVENANCE_SKIP_BUILD must be 0 or 1" >&2
    exit 2
    ;;
esac
if [[ "${skip_build}" = 0 ]]; then
  "${project_root}/scripts/build-release-candidate.sh"
fi
test -d "${bundle}"
test -d "${signed_xcframework}"
test -f "${audit_report}"

python3 "${project_root}/scripts/release-provenance.py" verify "${bundle}"

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/mojo-ios-release-provenance.XXXXXX")"
case "${fixture_root}" in
  "${TMPDIR:-/tmp}"/mojo-ios-release-provenance.*) ;;
  *)
    echo "refusing unexpected provenance fixture root: ${fixture_root}" >&2
    exit 2
    ;;
esac
cleanup_fixture_root() {
  rm -rf -- "${fixture_root}"
}
trap cleanup_fixture_root EXIT

extracted_root="${fixture_root}/extracted"
mkdir -p "${extracted_root}"
ditto -x -k \
  "${bundle}/MojoIOSCore.xcframework.zip" \
  "${extracted_root}"
codesign --verify --deep --strict --verbose=4 \
  "${extracted_root}/MojoIOSCore.xcframework"
echo "RELEASE_PROVENANCE_EXTRACTED_SIGNATURE_PASS valid=yes"

deterministic_bundle="${fixture_root}/deterministic"
mkdir -p "${deterministic_bundle}"
python3 "${project_root}/scripts/release-provenance.py" generate \
  --xcframework "${signed_xcframework}" \
  --audit-report "${audit_report}" \
  --metadata "${metadata}" \
  --output "${deterministic_bundle}" \
  --project-license "${project_root}/LICENSE" \
  --source-date-epoch "$(git -C "${project_root}" show -s --format=%ct HEAD)" \
  --upstream-revision "${project_root}/upstream/REVISION" \
  --upstream-root "${project_root}/.work/modular"
diff -qr "${bundle}" "${deterministic_bundle}"
echo "RELEASE_PROVENANCE_DETERMINISTIC_PASS same_signed_input=yes"

run_expected_verification_failure() {
  local fixture_name="$1"
  local expected_detail="$2"
  shift 2
  local fixture_bundle="${fixture_root}/${fixture_name}"
  local fixture_log="${fixture_root}/${fixture_name}.log"
  ditto "${bundle}" "${fixture_bundle}"
  "$@" "${fixture_bundle}"
  if python3 "${project_root}/scripts/release-provenance.py" \
    verify "${fixture_bundle}" >"${fixture_log}" 2>&1; then
    echo "release provenance fixture unexpectedly passed: ${fixture_name}" >&2
    exit 1
  fi
  grep -Fq "${expected_detail}" "${fixture_log}"
  echo "RELEASE_PROVENANCE_NEGATIVE_PASS fixture=${fixture_name}"
}

mutate_archive() {
  printf X >>"$1/MojoIOSCore.xcframework.zip"
}
remove_license() {
  rm -- "$1/LICENSES/Modular-LICENSE.txt"
}
remove_project_license() {
  rm -- "$1/LICENSES/mojo-ios-LICENSE.txt"
}
replace_project_license_declaration() {
  local fixture_bundle="$1"
  local sbom_path="${fixture_bundle}/SBOM.spdx.json"
  local checksums_path="${fixture_bundle}/SHA256SUMS"
  perl -0pi -e \
    's/"licenseDeclared": "Apache-2.0 WITH LLVM-exception"/"licenseDeclared": "MIT"/' \
    "${sbom_path}"
  local sbom_sha256
  sbom_sha256="$(shasum -a 256 "${sbom_path}" | awk '{ print $1 }')"
  perl -pi -e \
    "s/^[0-9a-f]{64}  SBOM[.]spdx[.]json\$/${sbom_sha256}  SBOM.spdx.json/" \
    "${checksums_path}"
}

run_expected_verification_failure \
  corrupted-archive \
  "release checksum mismatch: MojoIOSCore.xcframework.zip" \
  mutate_archive
run_expected_verification_failure \
  missing-license \
  "release bundle file set differs" \
  remove_license
run_expected_verification_failure \
  missing-project-license \
  "release bundle file set differs" \
  remove_project_license
run_expected_verification_failure \
  mismatched-project-license \
  "SPDX release package must declare Apache-2.0 WITH LLVM-exception" \
  replace_project_license_declaration

dirty_log="${fixture_root}/dirty.log"
if python3 "${project_root}/scripts/release-provenance.py" \
  verify "${bundle}" --require-clean >"${dirty_log}" 2>&1; then
  echo "dirty provenance fixture unexpectedly passed" >&2
  exit 1
fi
grep -Fq "clean project worktree is required" "${dirty_log}"
echo "RELEASE_PROVENANCE_NEGATIVE_PASS fixture=dirty-worktree"

run_signature_failure() {
  local fixture_name="$1"
  local expected_code="$2"
  local fixture_xcframework="${fixture_root}/${fixture_name}/MojoIOSCore.xcframework"
  local fixture_report="${fixture_root}/${fixture_name}.json"
  local fixture_log="${fixture_root}/${fixture_name}.log"
  mkdir -p "$(dirname "${fixture_xcframework}")"
  ditto "${signed_xcframework}" "${fixture_xcframework}"
  if [[ "${fixture_name}" = unsigned ]]; then
    codesign --remove-signature "${fixture_xcframework}"
  else
    codesign --force --sign - "${fixture_xcframework}"
  fi
  if python3 "${project_root}/scripts/audit-apple-distribution.py" \
    "${fixture_xcframework}" \
    --policy "${audit_policy}" \
    --output "${fixture_report}" \
    --provenance "deployment_target=15.0" \
    --provenance "optimization_level=3" \
    --provenance "upstream_revision=$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")" \
    >"${fixture_log}" 2>&1; then
    echo "release signature fixture unexpectedly passed: ${fixture_name}" >&2
    exit 1
  fi
  grep -Fq "code=${expected_code}" "${fixture_log}"
  echo "RELEASE_PROVENANCE_NEGATIVE_PASS fixture=${fixture_name} code=${expected_code}"
}

run_signature_failure unsigned missing_required_signature
run_signature_failure adhoc-resigned wrong_signing_team

echo \
  "RELEASE_PROVENANCE_GATE_PASS positive=1 deterministic=1 negative=7 signed=yes sbom=spdx-2.3 notices=yes"
