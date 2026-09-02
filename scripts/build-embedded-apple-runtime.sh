#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${project_root}/scripts/lib/apple-toolchain.sh"

sdk_name=""
target_triple=""
optimization_level=""
sanitizer_name=none
debug_level=none
metal_enabled=0
testing_enabled=0
output_directory=""
clang_path=""

usage() {
  cat <<'EOF'
Usage: build-embedded-apple-runtime.sh \
  --sdk macosx|iphoneos|iphonesimulator \
  --target-triple TRIPLE --optimization 0|3 \
  --output-directory PATH \
  [--debug none|full] [--sanitizer none|address|thread] \
  [--metal] [--testing] [--clang PATH]

Builds the canonical embedded Apple CompilerRT/AsyncRT source set as individual
objects and a deterministic libMojoAppleRuntime.a. It never selects semantic
capabilities or links an application.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --sdk) sdk_name="${2:-}"; shift 2 ;;
  --target-triple) target_triple="${2:-}"; shift 2 ;;
  --optimization) optimization_level="${2:-}"; shift 2 ;;
  --debug) debug_level="${2:-}"; shift 2 ;;
  --sanitizer) sanitizer_name="${2:-}"; shift 2 ;;
  --metal) metal_enabled=1; shift ;;
  --testing) testing_enabled=1; shift ;;
  --output-directory) output_directory="${2:-}"; shift 2 ;;
  --clang) clang_path="${2:-}"; shift 2 ;;
  --help|-h) usage; exit 0 ;;
  *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "${sdk_name}" in macosx|iphoneos|iphonesimulator) ;; *) usage >&2; exit 2 ;; esac
case "${optimization_level}" in 0|3) ;; *) usage >&2; exit 2 ;; esac
case "${debug_level}" in none|full) ;; *) usage >&2; exit 2 ;; esac
case "${sanitizer_name}" in none|address|thread) ;; *) usage >&2; exit 2 ;; esac
[[ -n "${target_triple}" && -n "${output_directory}" ]] || {
  usage >&2
  exit 2
}

case "${sdk_name}:${target_triple}" in
macosx:*apple-macos*) ;;
iphoneos:*apple-ios*-simulator) echo "device SDK cannot use a Simulator triple" >&2; exit 2 ;;
iphoneos:*apple-ios*) ;;
iphonesimulator:*apple-ios*-simulator) ;;
*) echo "SDK and target triple disagree: ${sdk_name} ${target_triple}" >&2; exit 2 ;;
esac

mojo_ios_select_apple_toolchain
if [[ -z "${clang_path}" ]]; then
  clang_path="$(xcrun --sdk "${sdk_name}" --find clang)"
fi
[[ -x "${clang_path}" ]] || {
  echo "Apple runtime compiler is not executable: ${clang_path}" >&2
  exit 1
}
sdk_path="$(xcrun --sdk "${sdk_name}" --show-sdk-path)"
[[ -d "${sdk_path}" ]] || {
  echo "Apple SDK path is missing: ${sdk_path}" >&2
  exit 1
}

upstream_root="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
[[ -d "${upstream_root}/.git" ]] || {
  echo "pinned upstream checkout is missing: ${upstream_root}" >&2
  exit 1
}

runtime_names=(CompilerRT Globals KGENAsyncRT AppleWorkQueue DeviceContext)
runtime_sources=(
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/CompilerRT.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Globals.c"
  "${upstream_root}/KGEN/lib/CompilerRT/Embedded/Apple/AsyncRT.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/AppleWorkQueue.c"
  "${upstream_root}/AsyncRT/lib/Runtime/Apple/DeviceContextCAPI.c"
)
if [[ "${metal_enabled}" = 1 ]]; then
  runtime_names+=(MetalDeviceContext)
  runtime_sources+=("${upstream_root}/AsyncRT/lib/Runtime/Apple/MetalDeviceContextCAPI.m")
fi
for runtime_source in "${runtime_sources[@]}"; do
  [[ -f "${runtime_source}" ]] || {
    echo "embedded runtime source is missing: ${runtime_source}" >&2
    exit 1
  }
done

mkdir -p "${output_directory}"
common_flags=(
  -target "${target_triple}"
  -isysroot "${sdk_path}"
  -O"${optimization_level}"
  -Wall
  -Wextra
  -Werror
  -I "${upstream_root}"
  -I "${upstream_root}/AsyncRT/include"
)
if [[ "${debug_level}" = full ]]; then
  common_flags+=(-g)
fi
if [[ "${metal_enabled}" = 1 ]]; then
  common_flags+=(-DASYNCRT_ENABLE_METAL=1)
fi
if [[ "${testing_enabled}" = 1 ]]; then
  common_flags+=(-DASYNCRT_ENABLE_TESTING=1)
fi
if [[ "${sanitizer_name}" != none ]]; then
  common_flags+=(-fsanitize="${sanitizer_name}")
fi

runtime_objects=()
for runtime_index in "${!runtime_sources[@]}"; do
  runtime_source="${runtime_sources[${runtime_index}]}"
  runtime_name="${runtime_names[${runtime_index}]}"
  runtime_object="${output_directory}/${runtime_name}.o"
  source_flags=(-std=c17)
  if [[ "${runtime_source}" = *.m ]]; then
    source_flags=(-fobjc-arc)
  fi
  "${clang_path}" \
    "${common_flags[@]}" \
    "${source_flags[@]}" \
    -c "${runtime_source}" \
    -o "${runtime_object}"
  runtime_objects+=("${runtime_object}")
done

archive_path="${output_directory}/libMojoAppleRuntime.a"
rm -f -- "${archive_path}"
xcrun libtool -static -D -o "${archive_path}" "${runtime_objects[@]}"

receipt_path="${output_directory}/runtime-build.tsv"
{
  printf 'key\tvalue\n'
  printf 'sdk\t%s\n' "${sdk_name}"
  printf 'target_triple\t%s\n' "${target_triple}"
  printf 'optimization\t%s\n' "${optimization_level}"
  printf 'debug\t%s\n' "${debug_level}"
  printf 'sanitizer\t%s\n' "${sanitizer_name}"
  printf 'metal\t%s\n' "${metal_enabled}"
  printf 'testing\t%s\n' "${testing_enabled}"
  printf 'clang\t%s\n' "${clang_path}"
  printf 'sdk_path\t%s\n' "${sdk_path}"
  for runtime_index in "${!runtime_sources[@]}"; do
    printf 'source.%s\t%s\n' \
      "${runtime_names[${runtime_index}]}" \
      "${runtime_sources[${runtime_index}]}"
  done
} >"${receipt_path}"

printf 'EMBEDDED_APPLE_RUNTIME_BUILD_PASS sdk=%s target=%s optimization=%s sanitizer=%s metal=%s testing=%s archive=%s\n' \
  "${sdk_name}" "${target_triple}" "${optimization_level}" \
  "${sanitizer_name}" "${metal_enabled}" "${testing_enabled}" \
  "${archive_path}"
