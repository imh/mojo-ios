#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${project_root}/.work/modular"
compiler_path="${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo"
stdlib_path="${upstream_root}/mojo/stdlib"
max_path="${upstream_root}/max/mojo"
probe_path="${project_root}/probes/IOSMetalVectorAddProbe.mojo"
harness_path="${project_root}/tests/MetalHostVectorAddSmoke.c"
output_root="${MOJO_IOS_METAL_OUTPUT_ROOT:-${project_root}/build/metal-gate}"
compiler_state_root="${MOJO_IOS_METAL_COMPILER_STATE_ROOT:-${project_root}/build/compiler-state/metal}"
optimization_level="${MOJO_IOS_METAL_OPTIMIZATION_LEVEL:-3}"
debug_level="${MOJO_IOS_METAL_DEBUG_LEVEL:-none}"
device_context_source="${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"
apple_work_queue_source="${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c"
metal_context_source="${upstream_root}/AsyncRT/lib/Runtime/Apple/MetalDeviceContextCAPI.m"
asyncrt_headers="${upstream_root}/AsyncRT/include"
compiler_rt_source="${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
kgen_asyncrt_source="${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c"
globals_source="${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c"

case "${optimization_level}" in 0|1|2|3) ;; *)
  echo "MOJO_IOS_METAL_OPTIMIZATION_LEVEL must be 0, 1, 2, or 3" >&2
  exit 2
esac
case "${debug_level}" in none|line-tables|full) ;; *)
  echo "MOJO_IOS_METAL_DEBUG_LEVEL must be none, line-tables, or full" >&2
  exit 2
esac

metal_compiler="${MOJO_IOS_METAL_COMPILER_PATH:-}"
if [[ -z "${metal_compiler}" ]]; then
  if resolved_metal_compiler="$(xcrun -f metal 2>/dev/null)" &&
    [[ -x "${resolved_metal_compiler}" ]] &&
    "${resolved_metal_compiler}" --version >/dev/null 2>&1; then
    metal_compiler="${resolved_metal_compiler}"
  else
    metal_component_description="$(
      xcodebuild -showComponent MetalToolchain -json 2>/dev/null
    )"
    metal_toolchain_search_path="$(
      plutil -extract toolchainSearchPath raw - \
        <<<"${metal_component_description}"
    )"
    installed_metal_compiler="${metal_toolchain_search_path}/Metal.xctoolchain/usr/bin/metal"
    if [[ ! -x "${installed_metal_compiler}" ]] ||
      ! "${installed_metal_compiler}" --version >/dev/null 2>&1; then
      echo "set MOJO_IOS_METAL_COMPILER_PATH to Apple's installed metal executable" >&2
      exit 2
    fi
    metal_compiler="${installed_metal_compiler}"
  fi
fi

test -x "${compiler_path}"
test -x "${metal_compiler}"
test -d "${stdlib_path}/std"
test -d "${max_path}/max"
test -f "${probe_path}"
test -f "${harness_path}"
test -f "${device_context_source}"
test -f "${apple_work_queue_source}"
test -f "${metal_context_source}"
mkdir -p "${output_root}" "${compiler_state_root}/data" \
  "${compiler_state_root}/cache"

compiler_command=(
  env -u MODULAR_HOME
  MOJO_METAL_COMPILER_PATH="${metal_compiler}"
  XDG_DATA_HOME="${compiler_state_root}/data"
  XDG_CACHE_HOME="${compiler_state_root}/cache"
  MODULAR_CACHE_DIR="${compiler_state_root}/cache/mojo"
  "${compiler_path}"
)

compile_mojo_probe() {
  local target_triple="$1"
  local target_arch="$2"
  local output_path="$3"
  local argument_dump_value=false
  if [[ -n "${MOJO_IOS_METAL_ARGUMENT_IR_OUTPUT:-}" ]]; then
    argument_dump_value=true
  fi
  "${compiler_command[@]}" build "${probe_path}" \
    -I "${stdlib_path}" \
    -I "${max_path}" \
    --emit object \
    --target-triple "${target_triple}" \
    --target-cpu "${target_arch}" \
    --target-accelerator "${target_arch}" \
    --optimization-level "${optimization_level}" \
    --debug-level "${debug_level}" \
    -DMOJO_IOS_DUMP_METAL_ARGUMENT_LLVM="${argument_dump_value}" \
    -o "${output_path}"
  local metal_library_count
  metal_library_count="$(
    rg -ao MTLB "${output_path}" | wc -l | tr -d '[:space:]'
  )"
  if [[ "${metal_library_count}" != 5 ]]; then
    echo "expected one Mojo object containing 5 Metal kernel libraries; got " \
      "${metal_library_count}" >&2
    exit 1
  fi
}

reject_unimplemented_metal4_target() {
  if rg -n '\{"apple-m[1-5]-metal4"|StaticString\("apple-m[1-5]-metal4"\)|comptime MetalM[1-5]Metal4|arch_name="apple-m[1-5]-metal4"' \
    "${upstream_root}/KGEN/lib/Target/Metal/MetalTraits.cpp" \
    "${upstream_root}/mojo/stdlib/std/gpu/host/info.mojo"; then
    echo "Metal 4 is still advertised by the AIR 2.4 backend" >&2
    exit 1
  fi
}

reject_unsupported_air_type() {
  local air_pass="${upstream_root}/KGEN/lib/Compiler/ObjectCompiler/LLVM/Transforms/MetalAIRPass.cpp"
  local metal_backend="${upstream_root}/KGEN/lib/Compiler/ObjectCompiler/Target/Metal/MetalBackend.cpp"
  if rg -n 'report_fatal_error' "${air_pass}"; then
    echo "Metal AIR still aborts on unsupported IR" >&2
    exit 1
  fi
  rg -Fq 'recordMetalAIRLoweringError' "${air_pass}"
  test "$(rg -c 'getMetalAIRLoweringError\(module\)' "${metal_backend}")" = 2
}

compile_runtime_variant() {
  local variant_name="$1"
  local sdk_name="$2"
  local target_triple="$3"

  xcrun --sdk "${sdk_name}" clang -target "${target_triple}" \
    -std=c17 -O3 -Wall -Wextra -Werror \
    -c "${apple_work_queue_source}" \
    -o "${output_root}/AppleWorkQueue-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang -target "${target_triple}" \
    -std=c17 -O3 -Wall -Wextra -Werror \
    -DASYNCRT_ENABLE_METAL=1 \
    -I "${asyncrt_headers}" \
    -c "${device_context_source}" \
    -o "${output_root}/DeviceContextCAPI-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang -target "${target_triple}" \
    -fobjc-arc -O3 -Wall -Wextra -Werror \
    -DASYNCRT_ENABLE_METAL=1 \
    -I "${asyncrt_headers}" \
    -c "${metal_context_source}" \
    -o "${output_root}/MetalDeviceContextCAPI-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang -target "${target_triple}" \
    -std=c17 -O3 -Wall -Wextra -Werror \
    -c "${compiler_rt_source}" \
    -o "${output_root}/CompilerRT-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang -target "${target_triple}" \
    -std=c17 -O3 -Wall -Wextra -Werror \
    -I "${upstream_root}" \
    -c "${kgen_asyncrt_source}" \
    -o "${output_root}/KGENAsyncRT-${variant_name}.o"
  xcrun --sdk "${sdk_name}" clang -target "${target_triple}" \
    -std=c17 -O3 -Wall -Wextra -Werror \
    -c "${globals_source}" \
    -o "${output_root}/Globals-${variant_name}.o"
}

reject_unimplemented_metal4_target
reject_unsupported_air_type
compile_mojo_probe arm64-apple-ios15.0 apple-m1 \
  "${output_root}/IOSMetalVectorAddProbe.o"
compile_runtime_variant iphoneos iphoneos arm64-apple-ios15.0
xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -dynamiclib \
  -Wl,-undefined,error \
  "${output_root}/IOSMetalVectorAddProbe.o" \
  "${output_root}/AppleWorkQueue-iphoneos.o" \
  "${output_root}/DeviceContextCAPI-iphoneos.o" \
  "${output_root}/MetalDeviceContextCAPI-iphoneos.o" \
  "${output_root}/CompilerRT-iphoneos.o" \
  "${output_root}/KGENAsyncRT-iphoneos.o" \
  "${output_root}/Globals-iphoneos.o" \
  -framework Foundation -framework Metal \
  -o "${output_root}/IOSMetalVectorAddProbe.dylib"
if nm -u "${output_root}/IOSMetalVectorAddProbe.dylib" | rg -q AsyncRT_; then
  echo "the iOS Metal probe has unresolved AsyncRT symbols" >&2
  exit 1
fi

compile_mojo_probe arm64-apple-ios15.0-simulator apple-m1 \
  "${output_root}/IOSMetalVectorAddProbe-simulator.o"
compile_runtime_variant iphonesimulator iphonesimulator \
  arm64-apple-ios15.0-simulator
xcrun --sdk iphonesimulator clang -target arm64-apple-ios15.0-simulator \
  -std=c17 -O3 -Wall -Wextra -Werror \
  -c "${harness_path}" \
  -o "${output_root}/MetalVectorAddSmoke-simulator-harness.o"
xcrun --sdk iphonesimulator clang -target arm64-apple-ios15.0-simulator \
  "${output_root}/IOSMetalVectorAddProbe-simulator.o" \
  "${output_root}/AppleWorkQueue-iphonesimulator.o" \
  "${output_root}/DeviceContextCAPI-iphonesimulator.o" \
  "${output_root}/MetalDeviceContextCAPI-iphonesimulator.o" \
  "${output_root}/CompilerRT-iphonesimulator.o" \
  "${output_root}/KGENAsyncRT-iphonesimulator.o" \
  "${output_root}/Globals-iphonesimulator.o" \
  "${output_root}/MetalVectorAddSmoke-simulator-harness.o" \
  -framework Foundation -framework Metal \
  -o "${output_root}/MetalVectorAddSmoke-simulator"
if [[ -n "${MOJO_IOS_METAL_SIMULATOR_ID:-}" ]]; then
  xcrun simctl spawn "${MOJO_IOS_METAL_SIMULATOR_ID}" \
    "${output_root}/MetalVectorAddSmoke-simulator"
else
  echo "set MOJO_IOS_METAL_SIMULATOR_ID to execute the linked Metal probe in a booted simulator"
fi

compile_mojo_probe arm64-apple-macosx15.0 apple-m1 \
  "${output_root}/MetalVectorAddProbe-macos.o"
compile_runtime_variant macos macosx arm64-apple-macosx15.0
xcrun --sdk macosx clang -target arm64-apple-macosx15.0 \
  -std=c17 -O3 -Wall -Wextra -Werror \
  -c "${harness_path}" -o "${output_root}/MetalHostVectorAddSmoke.o"
xcrun --sdk macosx clang -target arm64-apple-macosx15.0 \
  "${output_root}/MetalVectorAddProbe-macos.o" \
  "${output_root}/AppleWorkQueue-macos.o" \
  "${output_root}/DeviceContextCAPI-macos.o" \
  "${output_root}/MetalDeviceContextCAPI-macos.o" \
  "${output_root}/CompilerRT-macos.o" \
  "${output_root}/KGENAsyncRT-macos.o" \
  "${output_root}/Globals-macos.o" \
  "${output_root}/MetalHostVectorAddSmoke.o" \
  -framework Foundation -framework Metal \
  -o "${output_root}/MetalHostVectorAddSmoke"
if [[ -n "${MOJO_IOS_METAL_ARGUMENT_IR_OUTPUT:-}" ]]; then
  "${output_root}/MetalHostVectorAddSmoke" \
    >"${MOJO_IOS_METAL_ARGUMENT_IR_OUTPUT}"
  cat "${MOJO_IOS_METAL_ARGUMENT_IR_OUTPUT}"
else
  "${output_root}/MetalHostVectorAddSmoke"
fi

echo "verified the heterogeneous Mojo Metal argument and useful-MVP matrix on iOS linkage, ARM64 Simulator, and macOS GPU execution at O${optimization_level} debug=${debug_level}"
