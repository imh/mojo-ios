#!/bin/bash

# Source-built Mojo environment. This file intentionally does not select target
# triples or optimization flags; callers must keep those proof inputs visible.

mojo_ios_configure_source_mojo() {
  local project_root="$1"
  local state_namespace="$2"

  [[ "${state_namespace}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
    echo "invalid Mojo compiler-state namespace: ${state_namespace}" >&2
    return 2
  }

  MOJO_IOS_UPSTREAM_ROOT="${MOJO_IOS_UPSTREAM_ROOT:-${project_root}/.work/modular}"
  MOJO_IOS_MOJO_BINARY="${MOJO_IOS_MOJO_BINARY:-${MOJO_IOS_UPSTREAM_ROOT}/bazel-bin/KGEN/tools/mojo/mojo}"
  MOJO_IOS_STDLIB_PATH="${MOJO_IOS_STDLIB_PATH:-${MOJO_IOS_UPSTREAM_ROOT}/mojo/stdlib}"
  MOJO_IOS_MAX_MOJO_PATH="${MOJO_IOS_MAX_MOJO_PATH:-${MOJO_IOS_UPSTREAM_ROOT}/max/mojo}"
  MOJO_IOS_COMPILER_STATE_ROOT="${MOJO_IOS_COMPILER_STATE_ROOT:-${project_root}/build/compiler-state/${state_namespace}}"

  [[ -d "${MOJO_IOS_UPSTREAM_ROOT}/.git" ]] || {
    echo "pinned upstream checkout is missing: ${MOJO_IOS_UPSTREAM_ROOT}" >&2
    return 1
  }
  local expected_revision
  expected_revision="$(tr -d '[:space:]' <"${project_root}/upstream/REVISION")"
  local actual_revision
  actual_revision="$(git -C "${MOJO_IOS_UPSTREAM_ROOT}" rev-parse HEAD)"
  [[ "${actual_revision}" = "${expected_revision}" ]] || {
    echo "upstream revision mismatch: expected=${expected_revision} actual=${actual_revision}" >&2
    return 1
  }
  [[ -x "${MOJO_IOS_MOJO_BINARY}" ]] || {
    echo "source-built Mojo compiler is missing: ${MOJO_IOS_MOJO_BINARY}" >&2
    return 1
  }
  [[ -d "${MOJO_IOS_STDLIB_PATH}/std" ]] || {
    echo "Mojo standard library is missing: ${MOJO_IOS_STDLIB_PATH}" >&2
    return 1
  }
  [[ -d "${MOJO_IOS_MAX_MOJO_PATH}/max" ]] || {
    echo "MAX Mojo library is missing: ${MOJO_IOS_MAX_MOJO_PATH}" >&2
    return 1
  }

  mkdir -p \
    "${MOJO_IOS_COMPILER_STATE_ROOT}/data" \
    "${MOJO_IOS_COMPILER_STATE_ROOT}/cache"
  export MOJO_IOS_UPSTREAM_ROOT MOJO_IOS_MOJO_BINARY
  export MOJO_IOS_STDLIB_PATH MOJO_IOS_MAX_MOJO_PATH
  export MOJO_IOS_COMPILER_STATE_ROOT
}

mojo_ios_source_mojo() {
  [[ -n "${MOJO_IOS_MOJO_BINARY:-}" ]] || {
    echo "configure the source Mojo compiler before invoking it" >&2
    return 2
  }
  env -u MODULAR_HOME \
    XDG_DATA_HOME="${MOJO_IOS_COMPILER_STATE_ROOT}/data" \
    XDG_CACHE_HOME="${MOJO_IOS_COMPILER_STATE_ROOT}/cache" \
    MODULAR_CACHE_DIR="${MOJO_IOS_COMPILER_STATE_ROOT}/cache/mojo" \
    "${MOJO_IOS_MOJO_BINARY}" "$@"
}
