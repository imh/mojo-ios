#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"
upstream_url="${MOJO_UPSTREAM_URL:-https://github.com/modular/modular.git}"
checkout_root="${project_root}/.work/modular"

test -n "${revision}"

if [[ ! -e "${checkout_root}" ]]; then
  mkdir -p "$(dirname "${checkout_root}")"
  git clone --filter=blob:none "${upstream_url}" "${checkout_root}"
fi

test -d "${checkout_root}/.git"

if [[ -n "$(git -C "${checkout_root}" status --porcelain)" ]]; then
  echo "refusing to replace a dirty upstream checkout: ${checkout_root}" >&2
  exit 1
fi

git -C "${checkout_root}" fetch --depth=1 origin "${revision}"
git -C "${checkout_root}" checkout --detach "${revision}"

actual_revision="$(git -C "${checkout_root}" rev-parse HEAD)"
test "${actual_revision}" = "${revision}"

echo "pinned Modular checkout ready at ${checkout_root} (${actual_revision})"
