#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build/runtime-abi-census-tests"
mkdir -p "${build_root}"

python3 "${project_root}/scripts/runtime-abi-census.py"

missing_disposition="${build_root}/missing-disposition.tsv"
grep -v 'TimeTraceProfiler' \
  "${project_root}/config/runtime-abi-dispositions.tsv" \
  >"${missing_disposition}"
if python3 "${project_root}/scripts/runtime-abi-census.py" \
    --dispositions "${missing_disposition}" \
    --output "${build_root}/unexpected.tsv" \
    >"${build_root}/negative.out" 2>&1; then
  echo "runtime ABI census accepted an unclassified operation" >&2
  exit 1
fi
grep -Fq 'has 0 explicit dispositions' "${build_root}/negative.out"

awk -F '\t' 'NR > 1 { count[$3]++ } END {
  assert_count = count["implemented"] + count["compile_time_rejected"]
  assert_count += count["statically_unreachable"] + count["runtime_rejected"]
  if (assert_count != NR - 1) exit 1
}' "${project_root}/build/runtime-abi-census.tsv"

echo "RUNTIME_ABI_CENSUS_TEST_PASS negative_unclassified=yes"
