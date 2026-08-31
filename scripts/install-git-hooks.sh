#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks_path="${project_root}/.githooks"

git -C "${project_root}" rev-parse --show-toplevel >/dev/null
test -x "${hooks_path}/pre-commit"

git -C "${project_root}" config --local core.hooksPath .githooks

configured_hooks_path="$(
  git -C "${project_root}" config --local --get core.hooksPath
)"
if [[ "${configured_hooks_path}" != ".githooks" ]]; then
  echo "failed to configure repository-managed Git hooks" >&2
  exit 1
fi

echo "GIT_HOOKS_INSTALLED path=.githooks"
