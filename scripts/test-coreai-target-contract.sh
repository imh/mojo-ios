#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_root="${project_root}/.work/modular"

rg -Fq 'Core AI DeviceContext is not implemented because the standard MAX' \
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"

if rg -n 'CoreAIRegionPass|__mojo_coreai_semantic_|AsyncRT_CoreAI_(execute|enqueue)Matmul|ASYNCRT_APPLE_DEVICE_CONTEXT_COREAI|kCoreAILabel|DeviceKind\.COREAI|DeviceRef\.CoreAI|is_coreai' \
  "${upstream_root}/KGEN" "${upstream_root}/AsyncRT" \
  "${upstream_root}/Support" "${upstream_root}/max" \
  "${upstream_root}/mojo/stdlib"; then
  echo "premature Core AI compiler, runtime, or public target surface is present" >&2
  exit 1
fi

echo "COREAI_TARGET_CONTRACT_PASS target=unregistered public_surface=absent context=not-implemented graph=not-implemented fallback=none"
