#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_path="${project_root}/AGENTS.md"
ledger_path="${project_root}/docs/CAPABILITY_LEDGER.md"

test -f "${agents_path}"
test -f "${ledger_path}"

required_root_ids=(
  track.mojo-language-compiler
  track.stdlib-native
  track.max-standard
  track.embedded-runtime
  track.asyncrt-concurrency
  track.swift-abi-artifacts
  track.metal
  track.coreai
  track.targets
  track.distribution
  track.upstream-evidence
)

for root_id in "${required_root_ids[@]}"; do
  root_count="$(rg -F -c "\`${root_id}\`" "${ledger_path}")"
  if [[ "${root_count}" != 1 ]]; then
    echo "tracker root ${root_id} must occur exactly once; got ${root_count}" >&2
    exit 1
  fi
done

required_section_headings=(
  "## Mojo language and generic compiler lowering"
  "## Standard library and native dependencies"
  "## Standard MAX surface"
  "## Embedded runtime ABI and lifecycle"
  "## Async and concurrency"
  "## AOT artifacts and Swift/C ABI"
  "## Metal programmable accelerator backend"
  "## Core AI and Apple Neural Engine"
  "## Target and hardware matrix"
  "## App Store distribution"
  "## Upstream and release sustainability"
)

for section_heading in "${required_section_headings[@]}"; do
  rg -Fq "${section_heading}" "${ledger_path}"
done

required_remainder_ids=(
  runtime.abi-census
  cpu.language-conformance
  cpu.closure-remaining
  stdlib.target-sensitive-remaining
  max.mojo-library-remaining
  max.graph-runtime-remaining
  metal.resources-remaining
  upstream.non-ios-regression
)

for remainder_id in "${required_remainder_ids[@]}"; do
  rg -F "\`${remainder_id}\`" "${ledger_path}" | \
    rg -Fq "not decomposed yet"
done

delegated_tracker_paths=(
  docs/IOS_TARGET_POLICY_AUDIT.md
  docs/CONCURRENCY_GATE.md
  docs/ASYNC_GATE.md
  docs/METAL_FEASIBILITY_GATE.md
  docs/COREAI_MVP_GATE.md
  docs/COREAI_FEASIBILITY_GATE.md
  docs/APP_STORE_DISTRIBUTION_GATE.md
)

for delegated_tracker_path in "${delegated_tracker_paths[@]}"; do
  test -f "${project_root}/${delegated_tracker_path}"
  rg -Fq "$(basename "${delegated_tracker_path}")" "${ledger_path}"
done

rg -Fq "Progressive tracking is required" "${agents_path}"
rg -Fq "The canonical tracker root" "${agents_path}"
rg -Fq "verify-tracker-structure.sh" "${agents_path}"

while IFS= read -r linked_target; do
  linked_file="${linked_target%%#*}"
  test -f "${project_root}/docs/${linked_file}"
done < <(
  rg -o '\]\([A-Za-z0-9_./-]+\.md(#[A-Za-z0-9_-]+)?\)' \
    "${project_root}/docs/CAPABILITY_LEDGER.md" \
    "${project_root}/docs/ARBITRARY_AOT_MOJO_PLAN.md" \
    "${project_root}/docs/ROADMAP.md" | \
    sed -E 's/^[^:]+://; s/^\]\(//; s/\)$//' | \
    sort -u
)

if rg -q \
  'current build includes test|release runtime archive built separately|standard Mojo lowering fails explicitly' \
  "${project_root}/docs/ARBITRARY_AOT_MOJO_PLAN.md" \
  "${project_root}/docs/SUPPORT_CONTRACT.md"; then
  echo "tracker documentation contains a known stale status statement" >&2
  exit 1
fi

echo "TRACKER_STRUCTURE_PASS roots=${#required_root_ids[@]} delegated=${#delegated_tracker_paths[@]} explicit_remainders=${#required_remainder_ids[@]}"
