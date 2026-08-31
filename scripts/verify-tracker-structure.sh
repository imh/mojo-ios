#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_path="${project_root}/AGENTS.md"
ledger_path="${project_root}/docs/CAPABILITY_LEDGER.md"
hook_path="${project_root}/.githooks/pre-commit"
hook_installer_path="${project_root}/scripts/install-git-hooks.sh"
validator_path="${project_root}/scripts/validate-progress-tracker.py"
ci_path="${project_root}/.github/workflows/validate-tracker.yml"

test -f "${agents_path}"
test -f "${ledger_path}"
test -x "${hook_path}"
test -x "${hook_installer_path}"
test -f "${validator_path}"
test -f "${ci_path}"

grep -Fq "Progressive tracking is required" "${agents_path}"
grep -Fq "GitHub task-list hierarchy" "${agents_path}"
grep -Fq "verify-tracker-structure.sh" "${agents_path}"
grep -Fq "install-git-hooks" "${agents_path}"
grep -Fq "git checkout-index --all" "${hook_path}"
grep -Fq 'docs/*' "${hook_path}"
grep -Fq '.github/workflows/*tracker*' "${hook_path}"
grep -Fq 'core.hooksPath .githooks' "${hook_installer_path}"
grep -Fq 'verify-tracker = "./scripts/verify-tracker-structure.sh"' \
  "${project_root}/pixi.toml"
grep -Fq 'install-git-hooks = "./scripts/install-git-hooks.sh"' \
  "${project_root}/pixi.toml"
grep -Fq './scripts/verify-tracker-structure.sh' "${ci_path}"

if grep -ERq \
  'current build includes test|release runtime archive built separately|standard Mojo lowering fails explicitly|not decomposed' \
  "${project_root}/docs/ARBITRARY_AOT_MOJO_PLAN.md" \
  "${project_root}/docs/SUPPORT_CONTRACT.md" \
  "${project_root}/docs/CAPABILITY_LEDGER.md" \
  "${project_root}/docs/trackers"; then
  echo "tracker documentation contains a known stale status statement" >&2
  exit 1
fi

python3 "${validator_path}"
