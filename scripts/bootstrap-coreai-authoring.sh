#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
virtual_environment="${project_root}/.work/coreai-venv"
uv_cache_directory="${project_root}/.work/uv-cache"

command -v uv >/dev/null
mkdir -p "${project_root}/.work" "${uv_cache_directory}"

if [[ ! -x "${virtual_environment}/bin/python" ]]; then
  UV_CACHE_DIR="${uv_cache_directory}" uv venv \
    --python 3.11 "${virtual_environment}"
fi

UV_CACHE_DIR="${uv_cache_directory}" uv pip install \
  --python "${virtual_environment}/bin/python" \
  "coreai-core==1.0.0b2"

"${virtual_environment}/bin/python" - <<'PY'
import importlib.metadata
import sys

assert sys.version_info[:2] == (3, 11), sys.version
assert importlib.metadata.version("coreai-core") == "1.0.0b2"
print(f"Core AI authoring environment: Python {sys.version.split()[0]}, coreai-core 1.0.0b2")
PY
