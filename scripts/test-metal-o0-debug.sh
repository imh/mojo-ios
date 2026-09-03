#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"

upstream_root="${project_root}/.work/modular"
probe_path="${project_root}/probes/IOSMetalVectorAddProbe.mojo"
output_root="${project_root}/build/metal-o0-debug-gate"
pipeline_fixture="${upstream_root}/KGEN/test/kgen/object-compiler/metal-optimization-level.ll"
pipeline_tool="${upstream_root}/bazel-bin/KGEN/tools/kgen-llvm-opt/kgen-llvm-opt"
compiler_path="${upstream_root}/bazel-bin/KGEN/tools/mojo/mojo"
stdlib_path="${upstream_root}/mojo/stdlib"
max_path="${upstream_root}/max/mojo"

mkdir -p "${output_root}"
mojo_ios_select_apple_toolchain
mojo_ios_discover_metal_frontend
export MOJO_METAL_COMPILER_PATH="${MOJO_IOS_METAL_FRONTEND}"

test -x "${pipeline_tool}"
test -x "${compiler_path}"
test -f "${pipeline_fixture}"
"${project_root}/scripts/audit-ordinary-mojo-source.py" "${probe_path}"

"${pipeline_tool}" -O0 -S "${pipeline_fixture}" \
  -o "${output_root}/pipeline-o0.ll"
"${pipeline_tool}" -O3 -S "${pipeline_fixture}" \
  -o "${output_root}/pipeline-o3.ll"
rg -Fq 'define internal i32 @helper' "${output_root}/pipeline-o0.ll"
rg -Fq 'call i32 @helper' "${output_root}/pipeline-o0.ll"
rg -Fq 'define void @builtin_kernel' "${output_root}/pipeline-o0.ll"
rg -Fq 'extractelement <3 x i32> %thread_position_in_threadgroup_idx, i32 0' \
  "${output_root}/pipeline-o0.ll"
if rg -Fq 'call i32 @air.thread_position_in_threadgroup.x' \
  "${output_root}/pipeline-o0.ll"; then
  echo "O0 Metal legalization left a builtin call inside a helper" >&2
  exit 1
fi
if rg -q 'define internal i32 @helper|call i32 @helper' \
  "${output_root}/pipeline-o3.ll"; then
  echo "optimized Metal regression fixture did not fold its helper" >&2
  exit 1
fi
rg -Fq 'store i32 42' "${output_root}/pipeline-o3.ll"

MOJO_IOS_METAL_OUTPUT_ROOT="${output_root}/o0" \
MOJO_IOS_METAL_COMPILER_STATE_ROOT="${output_root}/compiler-state-o0" \
MOJO_IOS_METAL_OPTIMIZATION_LEVEL=0 \
MOJO_IOS_METAL_DEBUG_LEVEL=none \
  "${project_root}/scripts/test-metal-feasibility.sh"
nm "${output_root}/o0/MetalDeviceContextCAPI-macos.o" \
  >"${output_root}/o0/metal-runtime-symbols.txt"
rg -Fq '_AsyncRT_DeviceFunction_copyToConstantMemory' \
  "${output_root}/o0/metal-runtime-symbols.txt"
strings "${output_root}/o0/MetalDeviceContextCAPI-macos.o" \
  >"${output_root}/o0/metal-runtime-strings.txt"
rg -Fq 'Metal constant-memory mapping is not implemented' \
  "${output_root}/o0/metal-runtime-strings.txt"

MOJO_IOS_METAL_OUTPUT_ROOT="${output_root}/o3" \
MOJO_IOS_METAL_COMPILER_STATE_ROOT="${output_root}/compiler-state-o3" \
MOJO_IOS_METAL_OPTIMIZATION_LEVEL=3 \
MOJO_IOS_METAL_DEBUG_LEVEL=none \
  "${project_root}/scripts/test-metal-feasibility.sh"

line_table_root="${output_root}/line-tables"
mkdir -p "${line_table_root}"
"${project_root}/scripts/run-source-mojo.sh" --state metal-o0-line-tables -- \
  build "${probe_path}" \
  -I "${stdlib_path}" \
  -I "${max_path}" \
  --emit llvm \
  --target-triple arm64-apple-ios15.0 \
  --target-cpu apple-m1 \
  --target-accelerator apple-m1 \
  --optimization-level 0 \
  --debug-level=line-tables \
  -o "${line_table_root}/host.ll"
test "$(find "${line_table_root}" -maxdepth 1 -name '*.metal.ll' | wc -l | tr -d '[:space:]')" = 5
for metal_ir in "${line_table_root}"/*.metal.ll; do
  rg -Fq 'source_filename = "IOSMetalVectorAddProbe.mojo"' "${metal_ir}"
  rg -Fq '!DILocation(' "${metal_ir}"
done

"${project_root}/scripts/run-source-mojo.sh" --state metal-o0-line-object -- \
  build "${probe_path}" \
  -I "${stdlib_path}" \
  -I "${max_path}" \
  --emit object \
  --target-triple arm64-apple-ios15.0 \
  --target-cpu apple-m1 \
  --target-accelerator apple-m1 \
  --optimization-level 0 \
  --debug-level=line-tables \
  -o "${line_table_root}/probe.o"
"${project_root}/scripts/extract-metallibs.py" \
  "${line_table_root}/probe.o" "${line_table_root}/metallibs"
test "$(find "${line_table_root}/metallibs" -maxdepth 1 -name '*.metallib' | wc -l | tr -d '[:space:]')" = 5
debug_companions_with_source=0
for metal_library in "${line_table_root}/metallibs"/*.metallib; do
  "${MOJO_IOS_METAL_FRONTEND%/metal}/air-validate" "${metal_library}"
  debug_bundle="${metal_library}.dSYM"
  rm -rf "${debug_bundle}"
  "${MOJO_IOS_METAL_FRONTEND%/metal}/air-dsymutil" \
    "${metal_library}" -o "${debug_bundle}"
  debug_companion="${debug_bundle}/Contents/Resources/DWARF/$(basename "${metal_library}")"
  test -f "${debug_companion}"
  debug_strings="${debug_companion}.strings"
  strings "${debug_companion}" >"${debug_strings}"
  rg -Fq 'IOSMetalVectorAddProbe__' "${debug_strings}"
  if rg -Fq 'IOSMetalVectorAddProbe.mojo' "${debug_strings}"; then
    debug_companions_with_source=$((debug_companions_with_source + 1))
  fi
done
test "${debug_companions_with_source}" -ge 1

full_debug_diagnostic="${output_root}/full-debug.txt"
if MOJO_METAL_COMPILER_PATH=/usr/bin/false \
  "${project_root}/scripts/run-source-mojo.sh" --state metal-full-debug-negative -- \
    build "${probe_path}" \
    -I "${stdlib_path}" \
    -I "${max_path}" \
    --emit object \
    --target-triple arm64-apple-ios15.0 \
    --target-cpu apple-m1 \
    --target-accelerator apple-m1 \
    --optimization-level 0 \
    --debug-level=full \
    -o "${output_root}/full-debug.o" \
    >"${full_debug_diagnostic}" 2>&1; then
  echo "Metal full debug unexpectedly compiled" >&2
  exit 1
fi
rg -Fq 'Metal full debug information is not implemented' \
  "${full_debug_diagnostic}"
if rg -Fq 'Metal compiler failed while packaging AIR' \
  "${full_debug_diagnostic}"; then
  echo "full-debug rejection occurred after invoking Apple Metal" >&2
  exit 1
fi

for simulator_specification in \
  "iphone:${MOJO_IOS_METAL_IPHONE_SIMULATOR_ID:-}" \
  "ipad:${MOJO_IOS_METAL_IPAD_SIMULATOR_ID:-}"; do
  simulator_kind="${simulator_specification%%:*}"
  simulator_id="${simulator_specification#*:}"
  if [[ -n "${simulator_id}" ]]; then
    xcrun simctl boot "${simulator_id}" 2>/dev/null || true
    xcrun simctl bootstatus "${simulator_id}" -b
    xcrun simctl spawn "${simulator_id}" \
      "${output_root}/o0/MetalVectorAddSmoke-simulator"
    echo "METAL_O0_SIMULATOR_PASS kind=${simulator_kind} device=${simulator_id}"
  fi
done

"${project_root}/scripts/record-gate-evidence.py" \
  --gate metal-o0-debug \
  --result pass \
  --output "${project_root}/build/evidence/metal-o0-debug.json" \
  --field "metal_frontend=${MOJO_IOS_METAL_VERSION//$'\n'/; }" \
  --field 'optimization_levels=0,3' \
  --field 'debug_levels=none,line-tables,full-named-rejection' \
  --artifact "${output_root}/o0/IOSMetalVectorAddProbe.o" \
  --artifact "${output_root}/o3/IOSMetalVectorAddProbe.o" \
  --artifact "${line_table_root}/probe.o"

echo "METAL_O0_DEBUG_GATE_PASS o0=independent o3=regressed line_tables=packaged full_debug=named-rejection"
