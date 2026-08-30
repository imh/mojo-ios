#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checkout_root="${project_root}/.work/modular"
expected_revision="$(tr -d '[:space:]' < "${project_root}/upstream/REVISION")"

test -d "${checkout_root}/.git"
test "$(git -C "${checkout_root}" rev-parse HEAD)" = "${expected_revision}"

expected_index_path="$(mktemp -t mojo-ios-expected-index.XXXXXX)"
trap 'rm -f -- "${expected_index_path}"' EXIT
GIT_INDEX_FILE="${expected_index_path}" \
  git -C "${checkout_root}" read-tree HEAD

patch_count=0
for patch_path in "${project_root}"/patches/modular/*.patch; do
  test -f "${patch_path}"
  patch_count=$((patch_count + 1))

  if git -C "${checkout_root}" apply --check "${patch_path}" 2>/dev/null; then
    git -C "${checkout_root}" apply --intent-to-add "${patch_path}"
  elif git -C "${checkout_root}" apply --reverse --check "${patch_path}" 2>/dev/null; then
    echo "already applied: ${patch_path##*/}"
  else
    echo "patch is neither cleanly applicable nor already applied: ${patch_path}" >&2
    exit 1
  fi

  GIT_INDEX_FILE="${expected_index_path}" \
    git -C "${checkout_root}" apply --cached "${patch_path}"
done

test "${patch_count}" -gt 0
if ! GIT_INDEX_FILE="${expected_index_path}" \
    git -C "${checkout_root}" diff --quiet --no-ext-diff; then
  echo "upstream checkout contains changes outside the reviewed patch stack" >&2
  exit 1
fi
test -z "$(GIT_INDEX_FILE="${expected_index_path}" \
  git -C "${checkout_root}" ls-files --others --exclude-standard)"
git -C "${checkout_root}" diff --cached --quiet
git -C "${checkout_root}" diff --check
echo "verified ${patch_count} upstream patch"
