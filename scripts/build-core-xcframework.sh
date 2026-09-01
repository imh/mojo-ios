#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deployment_target="${MOJO_IOS_DEPLOYMENT_TARGET:-15.0}"
optimization_level="${MOJO_IOS_OPTIMIZATION_LEVEL:-3}"
mojo_binary="${MOJO_IOS_MOJO_BINARY:-mojo}"
mojo_stdlib_path="${MOJO_IOS_STDLIB_PATH:-}"
mojo_max_path="${MOJO_IOS_MAX_PATH:-}"
upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
mojo_max_kernels_path="${MOJO_IOS_MAX_KERNELS_PATH:-${upstream_root}/max/kernels/src}"
build_root="${MOJO_IOS_BUILD_ROOT:-${project_root}/build}"
case "${build_root}" in
  "${project_root}/build"|"${project_root}/build/"*) ;;
  *)
    echo "MOJO_IOS_BUILD_ROOT must be inside ${project_root}/build" >&2
    exit 2
    ;;
esac
case "/${build_root}/" in
  *"/../"*|*"/./"*)
    echo "MOJO_IOS_BUILD_ROOT must not contain dot path components" >&2
    exit 2
    ;;
esac
compiler_state_root="${build_root}/compiler-state"
compiler_data_root="${compiler_state_root}/data"
compiler_cache_root="${compiler_state_root}/cache"
device_root="${build_root}/iphoneos"
simulator_root="${build_root}/iphonesimulator"
xcframework_path="${build_root}/MojoIOSCore.xcframework"
device_library_path="${device_root}/libMojoIOSCore.a"
simulator_library_path="${simulator_root}/libMojoIOSCore.a"
source_path="${project_root}/mojo/MojoIOSCore.mojo"
runtime_source_path="${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
kgen_async_runtime_source_path="${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c"
globals_source_path="${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c"
apple_work_queue_source_path="${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c"
async_runtime_source_path="${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"
metal_runtime_source_path="${upstream_root}/AsyncRT/lib/Runtime/Apple/MetalDeviceContextCAPI.m"
async_runtime_headers_path="${upstream_root}/AsyncRT/include"
device_framework_path="${device_root}/MojoIOSCore.framework"
simulator_framework_path="${simulator_root}/MojoIOSCore.framework"

command -v "${mojo_binary}" >/dev/null
command -v xcrun >/dev/null
command -v xcodebuild >/dev/null
test -f "${runtime_source_path}"
test -f "${kgen_async_runtime_source_path}"
test -f "${globals_source_path}"
test -f "${apple_work_queue_source_path}"
test -f "${async_runtime_source_path}"
test -f "${metal_runtime_source_path}"
test -f "${async_runtime_headers_path}/AsyncRT/Runtime/DeviceContextCAPI.h"

if [[ -z "${mojo_max_path}" ]]; then
  echo "MOJO_IOS_MAX_PATH is required for max.algorithm.parallelize" >&2
  exit 2
fi

mkdir -p "${compiler_data_root}" "${compiler_cache_root}"

mojo_import_flags=()
mojo_command=(
  env
  XDG_DATA_HOME="${compiler_data_root}"
  XDG_CACHE_HOME="${compiler_cache_root}"
  MODULAR_CACHE_DIR="${compiler_cache_root}/mojo"
  "${mojo_binary}"
)
if [[ -n "${mojo_stdlib_path}" ]]; then
  test -d "${mojo_stdlib_path}/std"
  mojo_import_flags+=(-I "${mojo_stdlib_path}")
  # A pixi task sets MODULAR_HOME to the packaged Mojo 1.0 environment. The
  # pinned source compiler must not discover that incompatible std.mojoc.
  mojo_command=(
    env -u MODULAR_HOME
    XDG_DATA_HOME="${compiler_data_root}"
    XDG_CACHE_HOME="${compiler_cache_root}"
    MODULAR_CACHE_DIR="${compiler_cache_root}/mojo"
    "${mojo_binary}"
  )
fi
if [[ -n "${mojo_max_path}" ]]; then
  test -d "${mojo_max_path}/max"
  mojo_import_flags+=(-I "${mojo_max_path}")
fi
test -d "${mojo_max_kernels_path}/layout"
mojo_import_flags+=(-I "${mojo_max_kernels_path}")

case "${optimization_level}" in
  0|1|2|3) ;;
  *)
    echo "MOJO_IOS_OPTIMIZATION_LEVEL must be 0, 1, 2, or 3" >&2
    exit 2
    ;;
esac

mojo_debug_level="none"
if [[ "${optimization_level}" = "0" ]]; then
  mojo_debug_level="full"
fi

mkdir -p "${device_root}" "${simulator_root}"

"${mojo_command[@]}" build "${source_path}" \
  "${mojo_import_flags[@]}" \
  --target-triple="arm64-apple-ios${deployment_target}" \
  --target-cpu=generic \
  --optimization-level="${optimization_level}" \
  --debug-level="${mojo_debug_level}" \
  --emit object \
  -o "${device_root}/MojoIOSCore.o"

xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -c "${runtime_source_path}" \
  -o "${device_root}/KGENCompilerRTEmbedded.o"

xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -I "${upstream_root}" \
  -c "${kgen_async_runtime_source_path}" \
  -o "${device_root}/KGENCompilerRTAsyncRT.o"

xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -c "${apple_work_queue_source_path}" \
  -o "${device_root}/AsyncRTAppleWorkQueue.o"

xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -c "${globals_source_path}" \
  -o "${device_root}/KGENCompilerRTGlobals.o"

xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -DASYNCRT_ENABLE_METAL=1 \
  -I "${async_runtime_headers_path}" \
  -c "${async_runtime_source_path}" \
  -o "${device_root}/AsyncRTDeviceContextCAPI.o"

xcrun --sdk iphoneos clang \
  -target "arm64-apple-ios${deployment_target}" \
  -O"${optimization_level}" \
  -fobjc-arc \
  -Wall \
  -Wextra \
  -Werror \
  -DASYNCRT_ENABLE_METAL=1 \
  -I "${async_runtime_headers_path}" \
  -c "${metal_runtime_source_path}" \
  -o "${device_root}/AsyncRTMetalDeviceContextCAPI.o"

"${mojo_command[@]}" build "${source_path}" \
  "${mojo_import_flags[@]}" \
  --target-triple="arm64-apple-ios${deployment_target}-simulator" \
  --target-cpu=generic \
  --optimization-level="${optimization_level}" \
  --debug-level="${mojo_debug_level}" \
  --emit object \
  -o "${simulator_root}/MojoIOSCore.o"

xcrun --sdk iphonesimulator clang \
  -target "arm64-apple-ios${deployment_target}-simulator" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -c "${runtime_source_path}" \
  -o "${simulator_root}/KGENCompilerRTEmbedded.o"

xcrun --sdk iphonesimulator clang \
  -target "arm64-apple-ios${deployment_target}-simulator" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -I "${upstream_root}" \
  -c "${kgen_async_runtime_source_path}" \
  -o "${simulator_root}/KGENCompilerRTAsyncRT.o"

xcrun --sdk iphonesimulator clang \
  -target "arm64-apple-ios${deployment_target}-simulator" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -c "${apple_work_queue_source_path}" \
  -o "${simulator_root}/AsyncRTAppleWorkQueue.o"

xcrun --sdk iphonesimulator clang \
  -target "arm64-apple-ios${deployment_target}-simulator" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -c "${globals_source_path}" \
  -o "${simulator_root}/KGENCompilerRTGlobals.o"

xcrun --sdk iphonesimulator clang \
  -target "arm64-apple-ios${deployment_target}-simulator" \
  -O"${optimization_level}" \
  -std=c17 \
  -Wall \
  -Wextra \
  -Werror \
  -DASYNCRT_ENABLE_METAL=1 \
  -I "${async_runtime_headers_path}" \
  -c "${async_runtime_source_path}" \
  -o "${simulator_root}/AsyncRTDeviceContextCAPI.o"

xcrun --sdk iphonesimulator clang \
  -target "arm64-apple-ios${deployment_target}-simulator" \
  -O"${optimization_level}" \
  -fobjc-arc \
  -Wall \
  -Wextra \
  -Werror \
  -DASYNCRT_ENABLE_METAL=1 \
  -I "${async_runtime_headers_path}" \
  -c "${metal_runtime_source_path}" \
  -o "${simulator_root}/AsyncRTMetalDeviceContextCAPI.o"

test "${device_library_path}" = "${build_root}/iphoneos/libMojoIOSCore.a"
test "${simulator_library_path}" = \
  "${build_root}/iphonesimulator/libMojoIOSCore.a"
rm -f -- "${device_library_path}" "${simulator_library_path}"

xcrun libtool -static -D -o "${device_library_path}" \
  "${device_root}/MojoIOSCore.o" \
  "${device_root}/KGENCompilerRTEmbedded.o" \
  "${device_root}/KGENCompilerRTAsyncRT.o" \
  "${device_root}/KGENCompilerRTGlobals.o" \
  "${device_root}/AsyncRTAppleWorkQueue.o" \
  "${device_root}/AsyncRTDeviceContextCAPI.o" \
  "${device_root}/AsyncRTMetalDeviceContextCAPI.o"
xcrun libtool -static -D -o "${simulator_library_path}" \
  "${simulator_root}/MojoIOSCore.o" \
  "${simulator_root}/KGENCompilerRTEmbedded.o" \
  "${simulator_root}/KGENCompilerRTAsyncRT.o" \
  "${simulator_root}/KGENCompilerRTGlobals.o" \
  "${simulator_root}/AsyncRTAppleWorkQueue.o" \
  "${simulator_root}/AsyncRTDeviceContextCAPI.o" \
  "${simulator_root}/AsyncRTMetalDeviceContextCAPI.o"

"${project_root}/scripts/package-static-framework.sh" \
  "${device_library_path}" "${device_framework_path}" "${deployment_target}"
"${project_root}/scripts/package-static-framework.sh" \
  "${simulator_library_path}" "${simulator_framework_path}" "${deployment_target}"

if [[ -e "${xcframework_path}" ]]; then
  test "${xcframework_path}" = "${build_root}/MojoIOSCore.xcframework"
  rm -rf -- "${xcframework_path}"
fi

xcodebuild -create-xcframework \
  -framework "${device_framework_path}" \
  -framework "${simulator_framework_path}" \
  -output "${xcframework_path}"
python3 "${project_root}/scripts/normalize-xcframework.py" "${xcframework_path}"

echo "created ${xcframework_path}"
