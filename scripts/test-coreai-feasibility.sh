#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_root="${project_root}/build/coreai-gate"
compiled_directory="${output_root}/compiled"
swift_output_directory="${output_root}/swift"
swift_module_cache="${project_root}/.work/swift-module-cache"
coreai_python="${project_root}/.work/coreai-venv/bin/python"

: "${MOJO_IOS_COREAI_DEVELOPER_DIR:?Set MOJO_IOS_COREAI_DEVELOPER_DIR to the Xcode 27 Contents/Developer directory}"

test -d "${MOJO_IOS_COREAI_DEVELOPER_DIR}"
test -x "${coreai_python}"
export DEVELOPER_DIR="${MOJO_IOS_COREAI_DEVELOPER_DIR}"

xcode_version_output="$(xcodebuild -version)"
xcode_version="$(sed -n '1s/^Xcode //p' <<<"${xcode_version_output}")"
xcode_build="$(sed -n '2s/^Build version //p' <<<"${xcode_version_output}")"
xcode_major_version="${xcode_version%%.*}"
if [[ ! "${xcode_major_version}" =~ ^[0-9]+$ ]] || \
  (( xcode_major_version < 27 )); then
  echo "Core AI requires Xcode 27 or newer; selected Xcode ${xcode_version}" >&2
  exit 2
fi

metal_toolchain_component="$(xcodebuild -showComponent MetalToolchain)"
rg -Fq "Build Version: ${xcode_build}" <<<"${metal_toolchain_component}"
rg -Fq "Status: installed" <<<"${metal_toolchain_component}"

iphoneos_sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
iphoneos_sdk_major_version="${iphoneos_sdk_version%%.*}"
if [[ ! "${iphoneos_sdk_major_version}" =~ ^[0-9]+$ ]] || \
  (( iphoneos_sdk_major_version < 27 )); then
  echo "Core AI requires the iOS 27 SDK; selected ${iphoneos_sdk_version}" >&2
  exit 2
fi

coreai_build="$(xcrun --find coreai-build)"
test -x "${coreai_build}"
iphoneos_sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
test -d "${iphoneos_sdk_path}/System/Library/Frameworks/CoreAI.framework"

case "${output_root}" in
  "${project_root}/build/coreai-gate") ;;
  *)
    echo "refusing to replace unexpected Core AI output path: ${output_root}" >&2
    exit 2
    ;;
esac
rm -rf -- "${output_root}"
mkdir -p "${compiled_directory}" "${swift_output_directory}" \
  "${swift_module_cache}"

"${coreai_python}" "${project_root}/probes/CoreAIDirectGraphProbe.py" \
  "${output_root}/CoreAIDirectGraphProbe.aimodel" \
  --ir-output "${output_root}/CoreAIDirectGraphProbe.mlir"
rg -Fq "coreai.graph @main" "${output_root}/CoreAIDirectGraphProbe.mlir"
rg -Fq "coreai.batch_matmul" "${output_root}/CoreAIDirectGraphProbe.mlir"
rg -Fq "coreai.relu" "${output_root}/CoreAIDirectGraphProbe.mlir"

"${coreai_build}" compile \
  "${output_root}/CoreAIDirectGraphProbe.aimodel" \
  --output "${compiled_directory}" \
  --platform iOS \
  --min-deployment-version 27.0 \
  --preferred-compute neural-engine

"${coreai_build}" inspect \
  "${output_root}/CoreAIDirectGraphProbe.aimodel" \
  --json --ops --no-storage --no-compute \
  >"${output_root}/source-inspection.json"
"${coreai_build}" inspect \
  "${compiled_directory}/CoreAIDirectGraphProbe.h13g.aimodelc" \
  --json >"${output_root}/m1-inspection.json"

"${coreai_python}" \
  "${project_root}/probes/VerifyCoreAIFeasibilityArtifacts.py" \
  --source-inspection "${output_root}/source-inspection.json" \
  --m1-inspection "${output_root}/m1-inspection.json" \
  --compiled-directory "${compiled_directory}"

CLANG_MODULE_CACHE_PATH="${swift_module_cache}" \
  xcrun --sdk iphoneos swiftc \
  -module-cache-path "${swift_module_cache}" \
  -target arm64-apple-ios27.0 \
  -parse-as-library \
  -warnings-as-errors \
  -emit-library \
  "${project_root}/probes/CoreAISwiftRuntimeProbe.swift" \
  -o "${swift_output_directory}/CoreAISwiftRuntimeProbe.dylib"
file "${swift_output_directory}/CoreAISwiftRuntimeProbe.dylib" | \
  rg -Fq "Mach-O 64-bit dynamically linked shared library arm64"
otool -L "${swift_output_directory}/CoreAISwiftRuntimeProbe.dylib" | \
  rg -Fq "/System/Library/Frameworks/CoreAI.framework/CoreAI"

simulator_sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
if [[ -d "${simulator_sdk_path}/System/Library/Frameworks/CoreAI.framework" ]]; then
  CLANG_MODULE_CACHE_PATH="${swift_module_cache}" \
    xcrun --sdk iphonesimulator swiftc \
    -module-cache-path "${swift_module_cache}" \
    -target arm64-apple-ios27.0-simulator \
    -parse-as-library \
    -warnings-as-errors \
    -c "${project_root}/probes/CoreAISwiftRuntimeProbe.swift" \
    -o "${swift_output_directory}/CoreAISwiftRuntimeProbe-simulator.o"
else
  if CLANG_MODULE_CACHE_PATH="${swift_module_cache}" \
    xcrun --sdk iphonesimulator swiftc \
    -module-cache-path "${swift_module_cache}" \
    -target arm64-apple-ios27.0-simulator \
    -parse-as-library \
    -c "${project_root}/probes/CoreAISwiftRuntimeProbe.swift" \
    -o "${swift_output_directory}/CoreAISwiftRuntimeProbe-simulator.o" \
    >"${swift_output_directory}/simulator.stdout" \
    2>"${swift_output_directory}/simulator.stderr"; then
    echo "Core AI unexpectedly compiled against an SDK without CoreAI.framework" >&2
    exit 1
  fi
  rg -Fq "no such module 'CoreAI'" \
    "${swift_output_directory}/simulator.stderr"
fi

PYTHONFAULTHANDLER=1 "${coreai_python}" -X faulthandler \
  "${project_root}/probes/CoreAIHostRuntimeProbe.py" \
  "${output_root}/CoreAIDirectGraphProbe.aimodel"

echo "COREAI_FEASIBILITY_PASS graph=matmul-relu aot=ios27 swift=device-linked host=concurrent-errors-lifetimes ane=preferred"
