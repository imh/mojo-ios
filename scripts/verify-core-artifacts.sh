#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build"
device_library="${build_root}/iphoneos/libMojoIOSCore.a"
simulator_library="${build_root}/iphonesimulator/libMojoIOSCore.a"
xcframework_path="${build_root}/MojoIOSCore.xcframework"

test -f "${device_library}"
test -f "${simulator_library}"
test -f "${xcframework_path}/Info.plist"

xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_add$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_add$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_list_sum$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_list_sum$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_seeded_random$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_seeded_random$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_argument_count$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_argument_count$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_parallel_fill_squares$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_parallel_fill_squares$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_async_await_sum$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_async_await_sum$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_async_parallel_sum$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_async_parallel_sum$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_async_error_status$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_async_error_status$'
xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_print_diagnostic$'
xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_print_diagnostic$'
xcrun nm -gU "${device_library}" | grep -q ' _KGEN_CompilerRT_AlignedAlloc$'
xcrun nm -gU "${simulator_library}" | grep -q ' _KGEN_CompilerRT_AlignedAlloc$'
xcrun nm -gU "${device_library}" | grep -q ' _AsyncRT_DeviceContext_create$'
xcrun nm -gU "${simulator_library}" | grep -q ' _AsyncRT_DeviceContext_create$'
xcrun nm -gU "${device_library}" | grep -q ' _AsyncRT_DeviceContext_enqueueHostFunctionRange$'
xcrun nm -gU "${simulator_library}" | grep -q ' _AsyncRT_DeviceContext_enqueueHostFunctionRange$'
xcrun nm -gU "${device_library}" | grep -q ' _AsyncRT_DeviceContext_synchronize$'
xcrun nm -gU "${simulator_library}" | grep -q ' _AsyncRT_DeviceContext_synchronize$'
for metal_runtime_symbol in \
  AsyncRT_DeviceContext_createBuffer_async \
  AsyncRT_DeviceContext_loadFunction \
  AsyncRT_DeviceContext_enqueueFunctionDirect; do
  xcrun nm -gU "${device_library}" | grep -q " _${metal_runtime_symbol}$"
  xcrun nm -gU "${simulator_library}" | grep -q " _${metal_runtime_symbol}$"
done
for library_path in "${device_library}" "${simulator_library}"; do
  if xcrun nm -gU "${library_path}" | \
    grep -Eq ' _(AsyncRT_CoreAI_|mojo_ios_coreai_|__mojo_coreai_semantic_)'; then
    echo "project-specific Core AI graph ABI leaked into ${library_path}" >&2
    exit 1
  fi
done
xcrun nm -gU "${device_library}" | grep -q ' _KGEN_CompilerRT_AsyncRT_ParallelismLevel$'
xcrun nm -gU "${simulator_library}" | grep -q ' _KGEN_CompilerRT_AsyncRT_ParallelismLevel$'
xcrun nm -gU "${device_library}" | grep -q ' _KGEN_CompilerRT_AsyncRT_InitializeSpinWaiter$'
xcrun nm -gU "${simulator_library}" | grep -q ' _KGEN_CompilerRT_AsyncRT_InitializeSpinWaiter$'
for language_async_runtime_symbol in \
  KGEN_CompilerRT_AsyncRT_InitializeChain \
  KGEN_CompilerRT_AsyncRT_DestroyChain \
  KGEN_CompilerRT_AsyncRT_Complete \
  KGEN_CompilerRT_AsyncRT_Wait \
  KGEN_CompilerRT_AsyncRT_Wait_Timeout \
  KGEN_CompilerRT_AsyncRT_Execute \
  KGEN_CompilerRT_AsyncRT_AndThen; do
  xcrun nm -gU "${device_library}" | \
    grep -q " _${language_async_runtime_symbol}$"
  xcrun nm -gU "${simulator_library}" | \
    grep -q " _${language_async_runtime_symbol}$"
done
xcrun nm -gU "${device_library}" | grep -q ' _KGEN_CompilerRT_NumLogicalCores$'
xcrun nm -gU "${simulator_library}" | grep -q ' _KGEN_CompilerRT_NumLogicalCores$'
for runtime_symbol in \
  KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice \
  KGEN_CompilerRT_AsyncRT_GetOrCreateCPUDevice \
  KGEN_CompilerRT_AsyncRT_ReleaseCPUDevice; do
  xcrun nm -gU "${device_library}" | grep -q " _${runtime_symbol}$"
  xcrun nm -gU "${simulator_library}" | grep -q " _${runtime_symbol}$"
done
if xcrun nm -gU "${device_library}" | grep -q ' _mojo_ios_runtime_'; then
  echo "project-specific runtime symbols leaked into the device library" >&2
  exit 1
fi
if xcrun nm -gU "${simulator_library}" | grep -q ' _mojo_ios_runtime_'; then
  echo "project-specific runtime symbols leaked into the simulator library" >&2
  exit 1
fi

device_platform="$(xcrun otool -l "${build_root}/iphoneos/MojoIOSCore.o" | awk '/platform / { print $2; exit }')"
simulator_platform="$(xcrun otool -l "${build_root}/iphonesimulator/MojoIOSCore.o" | awk '/platform / { print $2; exit }')"
device_apple_work_queue_platform="$(xcrun otool -l "${build_root}/iphoneos/AsyncRTAppleWorkQueue.o" | awk '/platform / { print $2; exit }')"
simulator_apple_work_queue_platform="$(xcrun otool -l "${build_root}/iphonesimulator/AsyncRTAppleWorkQueue.o" | awk '/platform / { print $2; exit }')"
device_async_runtime_platform="$(xcrun otool -l "${build_root}/iphoneos/AsyncRTDeviceContextCAPI.o" | awk '/platform / { print $2; exit }')"
simulator_async_runtime_platform="$(xcrun otool -l "${build_root}/iphonesimulator/AsyncRTDeviceContextCAPI.o" | awk '/platform / { print $2; exit }')"
device_metal_runtime_platform="$(xcrun otool -l "${build_root}/iphoneos/AsyncRTMetalDeviceContextCAPI.o" | awk '/platform / { print $2; exit }')"
simulator_metal_runtime_platform="$(xcrun otool -l "${build_root}/iphonesimulator/AsyncRTMetalDeviceContextCAPI.o" | awk '/platform / { print $2; exit }')"

test "${device_platform}" = "2"
test "${simulator_platform}" = "7"
test "${device_apple_work_queue_platform}" = "2"
test "${simulator_apple_work_queue_platform}" = "7"
test "${device_async_runtime_platform}" = "2"
test "${simulator_async_runtime_platform}" = "7"
test "${device_metal_runtime_platform}" = "2"
test "${simulator_metal_runtime_platform}" = "7"

variant_count="$(/usr/libexec/PlistBuddy -c 'Print :AvailableLibraries' "${xcframework_path}/Info.plist" | grep -c 'Dict')"
test "${variant_count}" = "2"

echo "verified device platform=2, simulator platform=7, core/async exports, language AsyncRT, CPU/Metal runtime, and no project-specific Core AI graph ABI"
