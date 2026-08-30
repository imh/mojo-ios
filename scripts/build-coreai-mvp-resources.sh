#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_root="${project_root}/build/coreai-mvp"
compiled_root="${output_root}/compiled"
resource_root="${project_root}/Sources/MojoIOS/Resources"
asset_name="CoreAIMatmulMatmulF32.aimodel"
authoring_python="${project_root}/.work/coreai-venv/bin/python"

: "${MOJO_IOS_COREAI_DEVELOPER_DIR:?Set MOJO_IOS_COREAI_DEVELOPER_DIR to Xcode 27 Contents/Developer}"
export DEVELOPER_DIR="${MOJO_IOS_COREAI_DEVELOPER_DIR}"

test -x "${authoring_python}"
test -d "${resource_root}"
coreai_build="$(xcrun --find coreai-build)"
xcode_version_output="$(xcodebuild -version)"
xcode_version="$(sed -n '1s/^Xcode //p' <<<"${xcode_version_output}")"
xcode_build="$(sed -n '2s/^Build version //p' <<<"${xcode_version_output}")"
coreai_build_version="$(${coreai_build} --version)"
authoring_version="$(${authoring_python} -c 'import importlib.metadata; print(importlib.metadata.version("coreai-core"))')"
compiler_revision="$(git -C "${project_root}/.work/modular" rev-parse HEAD)"

case "${output_root}" in
  "${project_root}/build/coreai-mvp") ;;
  *) echo "refusing unexpected Core AI MVP output path" >&2; exit 2 ;;
esac
rm -rf -- "${output_root}"
mkdir -p "${compiled_root}"

"${authoring_python}" "${project_root}/probes/CoreAIMatmulMatmulModel.py" \
  "${output_root}/${asset_name}" \
  --ir-output "${output_root}/CoreAIMatmulMatmulF32.mlir"
test "$(rg -c 'coreai.batch_matmul' "${output_root}/CoreAIMatmulMatmulF32.mlir")" = 2
rg -Fq 'coreai.graph @main' "${output_root}/CoreAIMatmulMatmulF32.mlir"

"${coreai_build}" compile "${output_root}/${asset_name}" \
  --output "${compiled_root}" \
  --platform iOS \
  --min-deployment-version 27.0 \
  --preferred-compute neural-engine
"${coreai_build}" inspect "${output_root}/${asset_name}" \
  --json --ops --no-storage --no-compute \
  > "${output_root}/inspection.json"

PYTHONFAULTHANDLER=1 "${authoring_python}" -X faulthandler \
  "${project_root}/probes/CoreAIMatmulMatmulHostProbe.py" \
  "${output_root}/${asset_name}"

"${authoring_python}" "${project_root}/probes/GenerateCoreAIMVPManifest.py" \
  --asset "${output_root}/${asset_name}" \
  --output "${output_root}/CoreAIMVPManifest.json" \
  --compiler-revision "${compiler_revision}" \
  --xcode-version "${xcode_version}" \
  --xcode-build "${xcode_build}" \
  --coreai-build-version "${coreai_build_version}" \
  --authoring-version "${authoring_version}"

packaged_asset="${resource_root}/${asset_name}"
test "${packaged_asset}" = \
  "${project_root}/Sources/MojoIOS/Resources/CoreAIMatmulMatmulF32.aimodel"
rm -rf -- "${packaged_asset}"
ditto "${output_root}/${asset_name}" "${packaged_asset}"
cp "${output_root}/CoreAIMVPManifest.json" \
  "${resource_root}/CoreAIMVPManifest.json"

echo "COREAI_MVP_RESOURCE_PASS graph=matmul-matmul aot=ios27 package=hashed fallback=none"
