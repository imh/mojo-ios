#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_path="${project_root}/build/ReferenceApp/MojoIOSReferenceApp.xcarchive"
policy_path="${project_root}/config/distribution/reference-archive-audit-policy.json"
audit_script="${project_root}/scripts/audit-apple-distribution.py"
evidence_root="${project_root}/build/distribution-evidence"
report_path="${evidence_root}/reference-archive-audit.json"
second_report_path="${evidence_root}/reference-archive-audit-second.json"
skip_build="${MOJO_IOS_REFERENCE_SKIP_BUILD:-0}"
upstream_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"

case "${skip_build}" in
  0|1) ;;
  *)
    echo "MOJO_IOS_REFERENCE_SKIP_BUILD must be 0 or 1" >&2
    exit 2
    ;;
esac

if [[ "${skip_build}" = 0 ]]; then
  "${project_root}/scripts/build-reference-archive.sh"
fi

test -d "${archive_path}"
test -f "${policy_path}"
test -x "${audit_script}"
mkdir -p "${evidence_root}"

provenance_arguments=(
  --provenance "deployment_target=15.0"
  --provenance "optimization_level=3"
  --provenance "upstream_revision=${upstream_revision}"
)

run_audit() {
  local artifact_to_audit="$1"
  local policy_to_use="$2"
  local output_report="$3"
  python3 "${audit_script}" \
    "${artifact_to_audit}" \
    --policy "${policy_to_use}" \
    --output "${output_report}" \
    "${provenance_arguments[@]}"
}

run_expected_failure() {
  local fixture_name="$1"
  local expected_code="$2"
  local expected_subject="$3"
  local fixture_archive="${negative_root}/${fixture_name}/MojoIOSReferenceApp.xcarchive"
  local fixture_policy="${negative_root}/${fixture_name}/policy.json"
  local fixture_report="${negative_root}/reports/${fixture_name}.json"
  local fixture_log="${negative_root}/reports/${fixture_name}.log"

  if run_audit "${fixture_archive}" "${fixture_policy}" "${fixture_report}" \
    >"${fixture_log}" 2>&1; then
    echo "reference archive negative fixture unexpectedly passed: ${fixture_name}" >&2
    exit 1
  fi
  grep -Fq "code=${expected_code}" "${fixture_log}"
  grep -Fq "${expected_subject}" "${fixture_log}"
  grep -Fq '"result": "fail"' "${fixture_report}"
  echo "REFERENCE_ARCHIVE_NEGATIVE_PASS fixture=${fixture_name} code=${expected_code}"
}

run_audit "${archive_path}" "${policy_path}" "${report_path}"
run_audit "${archive_path}" "${policy_path}" "${second_report_path}"
cmp "${report_path}" "${second_report_path}"
rm -f -- "${second_report_path}"

negative_root="$(mktemp -d "${TMPDIR:-/tmp}/mojo-ios-reference-negative.XXXXXX")"
case "${negative_root}" in
  "${TMPDIR:-/tmp}"/mojo-ios-reference-negative.*) ;;
  *)
    echo "refusing unexpected reference fixture root: ${negative_root}" >&2
    exit 1
    ;;
esac

cleanup_negative_root() {
  rm -rf -- "${negative_root}"
}
trap cleanup_negative_root EXIT
mkdir -p "${negative_root}/reports"

for fixture_name in \
  forbidden-content \
  missing-metal \
  unsigned \
  resigned \
  toolchain-mismatch; do
  fixture_root="${negative_root}/${fixture_name}"
  mkdir -p "${fixture_root}"
  ditto "${archive_path}" "${fixture_root}/MojoIOSReferenceApp.xcarchive"
  cp "${policy_path}" "${fixture_root}/policy.json"
done

forbidden_app="${negative_root}/forbidden-content/MojoIOSReferenceApp.xcarchive/Products/Applications/MojoIOSReferenceApp.app"
cp \
  "${project_root}/Tests/distribution-fixtures/forbidden-source.txt" \
  "${forbidden_app}/Injected.mojo"
run_expected_failure \
  forbidden-content \
  forbidden_source_or_python_path \
  Injected.mojo

missing_metal_executable="${negative_root}/missing-metal/MojoIOSReferenceApp.xcarchive/Products/Applications/MojoIOSReferenceApp.app/MojoIOSReferenceApp"
perl -pi -e 's/MTLB/NOPE/g' "${missing_metal_executable}"
if rg -aq MTLB "${missing_metal_executable}"; then
  echo "missing-Metal fixture retained an embedded Metal library" >&2
  exit 1
fi
run_expected_failure \
  missing-metal \
  wrong_embedded_metal_library_count \
  MojoIOSReferenceApp

unsigned_app="${negative_root}/unsigned/MojoIOSReferenceApp.xcarchive/Products/Applications/MojoIOSReferenceApp.app"
codesign --remove-signature "${unsigned_app}"
run_expected_failure \
  unsigned \
  missing_required_signature \
  MojoIOSReferenceApp.xcarchive

resigned_app="${negative_root}/resigned/MojoIOSReferenceApp.xcarchive/Products/Applications/MojoIOSReferenceApp.app"
codesign --force --deep --sign - "${resigned_app}"
run_expected_failure \
  resigned \
  wrong_signing_team \
  MojoIOSReferenceApp.xcarchive

mismatched_policy="${negative_root}/toolchain-mismatch/policy.json"
plutil -replace expected_toolchain.xcode_build_version \
  -string MISMATCHED "${mismatched_policy}"
run_expected_failure \
  toolchain-mismatch \
  toolchain_mismatch \
  xcode_build_version

echo "REFERENCE_ARCHIVE_GATE_PASS positive=1 deterministic=1 negative=5"
