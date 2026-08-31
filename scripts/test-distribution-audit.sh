#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifact_path="${project_root}/build/MojoIOSCore.xcframework"
policy_path="${project_root}/config/distribution/current-xcframework-audit-policy.json"
audit_script="${project_root}/scripts/audit-apple-distribution.py"
evidence_root="${project_root}/build/distribution-evidence"
report_path="${evidence_root}/xcframework-audit.json"
second_report_path="${evidence_root}/xcframework-audit-second.json"
fixture_source_root="${project_root}/Tests/distribution-fixtures"
skip_build="${MOJO_IOS_DISTRIBUTION_SKIP_BUILD:-0}"
deployment_target="${MOJO_IOS_DEPLOYMENT_TARGET:-15.0}"
optimization_level="${MOJO_IOS_OPTIMIZATION_LEVEL:-3}"
upstream_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"

case "${skip_build}" in
  0|1) ;;
  *)
    echo "MOJO_IOS_DISTRIBUTION_SKIP_BUILD must be 0 or 1" >&2
    exit 2
    ;;
esac

if [[ "${skip_build}" = 0 ]]; then
  "${project_root}/scripts/build-source-core-xcframework.sh"
fi

test -d "${artifact_path}"
test -f "${policy_path}"
test -x "${audit_script}"
test -f "${fixture_source_root}/ForbiddenCompilerRuntime.c"
test -f "${fixture_source_root}/GenericObject.c"
test -f "${fixture_source_root}/PrivateANE.c"
test -f "${fixture_source_root}/TestRuntimeControl.c"
test -f "${fixture_source_root}/UnexpectedDependency.c"
test -f "${fixture_source_root}/forbidden-source.txt"

mkdir -p "${evidence_root}"

provenance_arguments=(
  --provenance "deployment_target=${deployment_target}"
  --provenance "optimization_level=${optimization_level}"
  --provenance "upstream_revision=${upstream_revision}"
)

run_audit() {
  local artifact_to_audit="$1"
  local output_report="$2"
  python3 "${audit_script}" \
    "${artifact_to_audit}" \
    --policy "${policy_path}" \
    --output "${output_report}" \
    "${provenance_arguments[@]}"
}

run_expected_failure() {
  local fixture_name="$1"
  local expected_code="$2"
  local expected_subject="$3"
  local fixture_artifact="${negative_root}/${fixture_name}/MojoIOSCore.xcframework"
  local fixture_report="${negative_root}/reports/${fixture_name}.json"
  local fixture_log="${negative_root}/reports/${fixture_name}.log"

  if run_audit "${fixture_artifact}" "${fixture_report}" \
    >"${fixture_log}" 2>&1; then
    echo "distribution negative fixture unexpectedly passed: ${fixture_name}" >&2
    exit 1
  fi
  grep -Fq "code=${expected_code}" "${fixture_log}"
  grep -Fq "${expected_subject}" "${fixture_log}"
  grep -Fq '"result": "fail"' "${fixture_report}"
  echo "DISTRIBUTION_NEGATIVE_PASS fixture=${fixture_name} code=${expected_code}"
}

"${project_root}/scripts/verify-core-artifacts.sh"
run_audit "${artifact_path}" "${second_report_path}"
cmp "${report_path}" "${second_report_path}"
rm -f -- "${second_report_path}"

negative_root="$(mktemp -d "${TMPDIR:-/tmp}/mojo-ios-distribution-negative.XXXXXX")"
case "${negative_root}" in
  "${TMPDIR:-/tmp}"/mojo-ios-distribution-negative.*) ;;
  *)
    echo "refusing unexpected distribution fixture root: ${negative_root}" >&2
    exit 1
    ;;
esac

cleanup_negative_root() {
  rm -rf -- "${negative_root}"
}
trap cleanup_negative_root EXIT
mkdir -p "${negative_root}/reports"

for fixture_name in \
  forbidden-source \
  undeclared-accelerator \
  test-runtime-control \
  private-ane \
  compiler-runtime \
  wrong-platform \
  wrong-minimum-os \
  unexpected-slice \
  unexpected-dependency; do
  mkdir -p "${negative_root}/${fixture_name}"
  ditto \
    "${artifact_path}" \
    "${negative_root}/${fixture_name}/MojoIOSCore.xcframework"
done

cp \
  "${fixture_source_root}/forbidden-source.txt" \
  "${negative_root}/forbidden-source/MojoIOSCore.xcframework/Injected.mojo"
run_expected_failure \
  forbidden-source \
  forbidden_source_or_python_path \
  Injected.mojo

cp \
  "${fixture_source_root}/forbidden-source.txt" \
  "${negative_root}/undeclared-accelerator/MojoIOSCore.xcframework/Undeclared.metallib"
run_expected_failure \
  undeclared-accelerator \
  undeclared_accelerator_artifact \
  Undeclared.metallib

test_runtime_object="${negative_root}/TestRuntimeControl.o"
xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -Wall -Wextra -Werror \
  -c "${fixture_source_root}/TestRuntimeControl.c" \
  -o "${test_runtime_object}"
xcrun ar rcs \
  "${negative_root}/test-runtime-control/MojoIOSCore.xcframework/ios-arm64/libMojoIOSCore.a" \
  "${test_runtime_object}"
run_expected_failure \
  test-runtime-control \
  test_runtime_symbol \
  AsyncRT_Test_InjectedControl

private_ane_object="${negative_root}/PrivateANE.o"
xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -Wall -Wextra -Werror \
  -c "${fixture_source_root}/PrivateANE.c" \
  -o "${private_ane_object}"
xcrun ar rcs \
  "${negative_root}/private-ane/MojoIOSCore.xcframework/ios-arm64/libMojoIOSCore.a" \
  "${private_ane_object}"
run_expected_failure \
  private-ane \
  private_ane_symbol \
  ANECompilerInjectedPrivateInterface
grep -Fq \
  'code=project_coreai_symbol' \
  "${negative_root}/reports/private-ane.log"

compiler_runtime_object="${negative_root}/ForbiddenCompilerRuntime.o"
xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -Wall -Wextra -Werror \
  -c "${fixture_source_root}/ForbiddenCompilerRuntime.c" \
  -o "${compiler_runtime_object}"
xcrun ar rcs \
  "${negative_root}/compiler-runtime/MojoIOSCore.xcframework/ios-arm64/libMojoIOSCore.a" \
  "${compiler_runtime_object}"
run_expected_failure \
  compiler-runtime \
  compiler_jit_symbol \
  LLVMCreateExecutionEngineForModule
compiler_runtime_log="${negative_root}/reports/compiler-runtime.log"
grep -Fq 'code=python_runtime_symbol' "${compiler_runtime_log}"
grep -Fq 'code=dynamic_loading_symbol' "${compiler_runtime_log}"

wrong_platform_object="${negative_root}/WrongPlatform.o"
xcrun --sdk macosx clang \
  -target arm64-apple-macosx15.0 \
  -Wall -Wextra -Werror \
  -c "${fixture_source_root}/GenericObject.c" \
  -o "${wrong_platform_object}"
xcrun ar rcs \
  "${negative_root}/wrong-platform/MojoIOSCore.xcframework/ios-arm64/libMojoIOSCore.a" \
  "${wrong_platform_object}"
run_expected_failure \
  wrong-platform \
  wrong_platform \
  WrongPlatform.o

wrong_minimum_object="${negative_root}/WrongMinimumOS.o"
xcrun --sdk iphoneos clang \
  -target arm64-apple-ios16.0 \
  -Wall -Wextra -Werror \
  -c "${fixture_source_root}/GenericObject.c" \
  -o "${wrong_minimum_object}"
xcrun ar rcs \
  "${negative_root}/wrong-minimum-os/MojoIOSCore.xcframework/ios-arm64/libMojoIOSCore.a" \
  "${wrong_minimum_object}"
run_expected_failure \
  wrong-minimum-os \
  wrong_minimum_os \
  WrongMinimumOS.o

cp -R \
  "${negative_root}/unexpected-slice/MojoIOSCore.xcframework/ios-arm64" \
  "${negative_root}/unexpected-slice/MojoIOSCore.xcframework/ios-arm64-unexpected"
unexpected_slice_plist="${negative_root}/unexpected-slice/MojoIOSCore.xcframework/Info.plist"
/usr/libexec/PlistBuddy \
  -c 'Add :AvailableLibraries:2 dict' \
  -c 'Add :AvailableLibraries:2:LibraryIdentifier string ios-arm64-unexpected' \
  -c 'Add :AvailableLibraries:2:LibraryPath string libMojoIOSCore.a' \
  -c 'Add :AvailableLibraries:2:BinaryPath string libMojoIOSCore.a' \
  -c 'Add :AvailableLibraries:2:HeadersPath string Headers' \
  -c 'Add :AvailableLibraries:2:SupportedPlatform string ios' \
  -c 'Add :AvailableLibraries:2:SupportedArchitectures array' \
  -c 'Add :AvailableLibraries:2:SupportedArchitectures:0 string arm64' \
  "${unexpected_slice_plist}"
run_expected_failure \
  unexpected-slice \
  unexpected_slice \
  ios-arm64-unexpected

unexpected_dependency_library="${negative_root}/libUnexpectedNetwork.dylib"
xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -dynamiclib \
  -Wall -Wextra -Werror \
  -framework Network \
  "${fixture_source_root}/UnexpectedDependency.c" \
  -o "${unexpected_dependency_library}"
cp \
  "${unexpected_dependency_library}" \
  "${negative_root}/unexpected-dependency/MojoIOSCore.xcframework/ios-arm64/libUnexpectedNetwork.dylib"
run_expected_failure \
  unexpected-dependency \
  unexpected_dependency \
  Network.framework

echo "DISTRIBUTION_AUDIT_GATE_PASS positive=1 deterministic=1 negative=9"
