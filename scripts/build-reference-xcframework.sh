#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build"
reference_root="${build_root}/reference-xcframework"
device_root="${reference_root}/iphoneos"
simulator_root="${reference_root}/iphonesimulator"
xcframework_path="${build_root}/MojoIOSReference.xcframework"
core_device_library="${build_root}/MojoIOSCore.xcframework/ios-arm64/MojoIOSCore.framework/MojoIOSCore"
core_simulator_library="${build_root}/MojoIOSCore.xcframework/ios-arm64-simulator/MojoIOSCore.framework/MojoIOSCore"
metal_device_object="${build_root}/metal-gate/IOSMetalVectorAddProbe.o"
metal_simulator_object="${build_root}/metal-gate/IOSMetalVectorAddProbe-simulator.o"
device_library="${device_root}/libMojoIOSReference.a"
simulator_library="${simulator_root}/libMojoIOSReference.a"
device_framework="${device_root}/MojoIOSCore.framework"
simulator_framework="${simulator_root}/MojoIOSCore.framework"

for required_artifact in \
  "${core_device_library}" \
  "${core_simulator_library}" \
  "${metal_device_object}" \
  "${metal_simulator_object}"; do
  test -f "${required_artifact}"
done

mkdir -p "${device_root}" "${simulator_root}"
rm -f -- "${device_library}" "${simulator_library}"
xcrun libtool -static \
  -o "${device_library}" \
  "${core_device_library}" \
  "${metal_device_object}"
xcrun libtool -static \
  -o "${simulator_library}" \
  "${core_simulator_library}" \
  "${metal_simulator_object}"

for reference_library in "${device_library}" "${simulator_library}"; do
  xcrun nm -gU "${reference_library}" | grep -q ' _mojo_ios_add$'
  xcrun nm -gU "${reference_library}" | grep -q ' _mojo_ios_metal_vector_add$'
done

"${project_root}/scripts/package-static-framework.sh" \
  "${device_library}" "${device_framework}" "15.0"
"${project_root}/scripts/package-static-framework.sh" \
  "${simulator_library}" "${simulator_framework}" "15.0"

case "${xcframework_path}" in
  "${project_root}/build/MojoIOSReference.xcframework") ;;
  *)
    echo "refusing unexpected reference XCFramework path: ${xcframework_path}" >&2
    exit 2
    ;;
esac
rm -rf -- "${xcframework_path}"
xcodebuild -create-xcframework \
  -framework "${device_framework}" \
  -framework "${simulator_framework}" \
  -output "${xcframework_path}"

variant_count="$(
  /usr/libexec/PlistBuddy -c 'Print :AvailableLibraries' \
    "${xcframework_path}/Info.plist" | grep -c Dict
)"
test "${variant_count}" = 2

upstream_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"
python3 "${project_root}/scripts/audit-apple-distribution.py" \
  "${xcframework_path}" \
  --policy "${project_root}/config/distribution/reference-xcframework-audit-policy.json" \
  --output "${build_root}/distribution-evidence/reference-xcframework-audit.json" \
  --provenance "deployment_target=15.0" \
  --provenance "optimization_level=3" \
  --provenance "upstream_revision=${upstream_revision}"

echo "REFERENCE_XCFRAMEWORK_BUILD_PASS variants=2 cpu=yes metal=yes audited=yes"
