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

MOJO_IOS_METAL_OUTPUT_ROOT="${output_root}/full-o0" \
MOJO_IOS_METAL_COMPILER_STATE_ROOT="${output_root}/compiler-state-full-o0" \
MOJO_IOS_METAL_OPTIMIZATION_LEVEL=0 \
MOJO_IOS_METAL_DEBUG_LEVEL=full \
  "${project_root}/scripts/test-metal-feasibility.sh"

MOJO_IOS_METAL_OUTPUT_ROOT="${output_root}/full-o3" \
MOJO_IOS_METAL_COMPILER_STATE_ROOT="${output_root}/compiler-state-full-o3" \
MOJO_IOS_METAL_OPTIMIZATION_LEVEL=3 \
MOJO_IOS_METAL_DEBUG_LEVEL=full \
  "${project_root}/scripts/test-metal-feasibility.sh"

inspect_full_debug_ir() {
  local variant_name="$1"
  local optimization_level="$2"
  local ir_root="${output_root}/${variant_name}/ir"
  mkdir -p "${ir_root}"
  "${project_root}/scripts/run-source-mojo.sh" \
    --state "metal-${variant_name}-ir" -- \
    build "${probe_path}" \
    -I "${stdlib_path}" \
    -I "${max_path}" \
    --emit llvm \
    --target-triple arm64-apple-ios15.0 \
    --target-cpu apple-m1 \
    --target-accelerator apple-m1 \
    --optimization-level "${optimization_level}" \
    --debug-level=full \
    -o "${ir_root}/host.ll"

  test "$(find "${ir_root}" -maxdepth 1 -name '*.metal.ll' | wc -l | tr -d '[:space:]')" = 5
  local local_variable_count=0
  local basic_type_count=0
  local derived_type_count=0
  local lexical_scope_count=0
  for metal_ir in "${ir_root}"/*.metal.ll; do
    rg -Fq 'source_filename = "IOSMetalVectorAddProbe.mojo"' "${metal_ir}"
    rg -Fq '!DICompileUnit(' "${metal_ir}"
    rg -Fq '!DISubprogram(' "${metal_ir}"
    rg -Fq '!DILocation(' "${metal_ir}"
    if rg -Fq '!DILocalVariable(' "${metal_ir}"; then
      local_variable_count=$((local_variable_count + 1))
    fi
    if rg -Fq '!DIBasicType(' "${metal_ir}"; then
      basic_type_count=$((basic_type_count + 1))
    fi
    if rg -Fq '!DIDerivedType(' "${metal_ir}"; then
      derived_type_count=$((derived_type_count + 1))
    fi
    if rg -Fq '!DILexicalBlock(' "${metal_ir}"; then
      lexical_scope_count=$((lexical_scope_count + 1))
    fi
    if rg -q 'asm sideeffect "nop"|llvm\.dbg\.label' "${metal_ir}"; then
      echo "AIR full-debug IR retained an unsupported synthetic line marker" >&2
      exit 1
    fi
  done
  if [[ "${variant_name}" == full-o0 ]]; then
    test "${local_variable_count}" -ge 1
    test "${basic_type_count}" -ge 1
    test "${derived_type_count}" -ge 1
    test "${lexical_scope_count}" -ge 1
  fi
}

inspect_full_debug_ir full-o0 0
inspect_full_debug_ir full-o3 3

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

inspect_full_debug_variant() {
  local variant_name="$1"
  local variant_root="${output_root}/${variant_name}"
  local metallib_root="${variant_root}/metallibs"
  mkdir -p "${metallib_root}"
  "${project_root}/scripts/extract-metallibs.py" \
    "${variant_root}/IOSMetalVectorAddProbe.o" "${metallib_root}"
  test "$(find "${metallib_root}" -maxdepth 1 -name '*.metallib' | wc -l | tr -d '[:space:]')" = 5

  local source_count=0
  for metal_library in "${metallib_root}"/*.metallib; do
    "${MOJO_IOS_METAL_FRONTEND%/metal}/air-validate" "${metal_library}"
    local debug_bundle="${metal_library}.dSYM"
    rm -rf "${debug_bundle}"
    "${MOJO_IOS_METAL_FRONTEND%/metal}/air-dsymutil" \
      "${metal_library}" -o "${debug_bundle}"
    local debug_companion="${debug_bundle}/Contents/Resources/DWARF/$(basename "${metal_library}")"
    test -f "${debug_companion}"
    local debug_strings="${debug_companion}.strings"
    strings "${debug_companion}" >"${debug_strings}"
    rg -Fq 'IOSMetalVectorAddProbe__' "${debug_strings}"
    local debug_dump="${metal_library}.debug.txt"
    "${MOJO_IOS_METAL_FRONTEND%/metal}/air-objdump" \
      --metallib --disassemble --line-numbers --debug-vars=ascii \
      --dsym="${debug_bundle}" "${metal_library}" >"${debug_dump}"
    rg -Fq 'IOSMetalVectorAddProbe__' "${debug_dump}"
    if rg -Fq 'IOSMetalVectorAddProbe.mojo' "${debug_strings}"; then
      source_count=$((source_count + 1))
    fi
  done
  test "${source_count}" -ge 1
}

inspect_full_debug_variant full-o0
inspect_full_debug_variant full-o3

for simulator_specification in \
  "iphone:${MOJO_IOS_METAL_IPHONE_SIMULATOR_ID:-}" \
  "ipad:${MOJO_IOS_METAL_IPAD_SIMULATOR_ID:-}"; do
  simulator_kind="${simulator_specification%%:*}"
  simulator_id="${simulator_specification#*:}"
  if [[ -n "${simulator_id}" ]]; then
    xcrun simctl boot "${simulator_id}" 2>/dev/null || true
    xcrun simctl bootstatus "${simulator_id}" -b
    for variant_name in o0 o3 full-o0 full-o3; do
      xcrun simctl spawn "${simulator_id}" \
        "${output_root}/${variant_name}/MetalVectorAddSmoke-simulator"
      echo "METAL_DEBUG_SIMULATOR_PASS kind=${simulator_kind} device=${simulator_id} variant=${variant_name}"
    done
  fi
done

"${project_root}/scripts/record-gate-evidence.py" \
  --gate metal-o0-debug \
  --result pass \
  --output "${project_root}/build/evidence/metal-o0-debug.json" \
  --field "metal_frontend=${MOJO_IOS_METAL_VERSION//$'\n'/; }" \
  --field 'optimization_levels=0,3' \
  --field 'debug_levels=none,line-tables,full' \
  --artifact "${output_root}/o0/IOSMetalVectorAddProbe.o" \
  --artifact "${output_root}/o3/IOSMetalVectorAddProbe.o" \
  --artifact "${line_table_root}/probe.o" \
  --artifact "${output_root}/full-o0/IOSMetalVectorAddProbe.o" \
  --artifact "${output_root}/full-o3/IOSMetalVectorAddProbe.o"

echo "METAL_O0_DEBUG_GATE_PASS o0=independent o3=regressed line_tables=packaged full_debug=o0,o3-packaged-and-inspected"
