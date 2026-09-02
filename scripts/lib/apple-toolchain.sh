#!/bin/bash

# Shared Apple toolchain discovery for repository scripts. This file is meant
# to be sourced; callers retain control of target, SDK, and build flags.

mojo_ios_tooling_error() {
  printf 'mojo-ios toolchain: %s\n' "$*" >&2
  return 1
}

mojo_ios_xcode_major_version() {
  local developer_directory="$1"
  local version_output
  version_output="$(
    DEVELOPER_DIR="${developer_directory}" \
      xcodebuild -version 2>/dev/null
  )" || return 1
  sed -n 's/^Xcode \([0-9][0-9]*\).*/\1/p' <<<"${version_output}" | head -n 1
}

mojo_ios_select_apple_toolchain() {
  local selected_developer_directory="${DEVELOPER_DIR:-}"
  local stable_developer_directory="/Applications/Xcode.app/Contents/Developer"
  local beta_developer_directory="/Applications/Xcode-beta.app/Contents/Developer"

  if [[ -z "${selected_developer_directory}" ]]; then
    local stable_major_version=""
    if [[ -d "${stable_developer_directory}" ]]; then
      stable_major_version="$(
        mojo_ios_xcode_major_version "${stable_developer_directory}" || true
      )"
    fi
    if [[ "${stable_major_version}" =~ ^[0-9]+$ ]] && \
      (( stable_major_version >= 27 )); then
      selected_developer_directory="${stable_developer_directory}"
    else
      selected_developer_directory="${beta_developer_directory}"
    fi
  fi

  [[ -d "${selected_developer_directory}" ]] || \
    mojo_ios_tooling_error \
      "selected DEVELOPER_DIR does not exist: ${selected_developer_directory}" || \
    return 1

  export DEVELOPER_DIR="${selected_developer_directory}"
  MOJO_IOS_SELECTED_XCODE_VERSION="$(xcodebuild -version)" || \
    mojo_ios_tooling_error \
      "xcodebuild failed for ${selected_developer_directory}" || return 1
  export MOJO_IOS_SELECTED_XCODE_VERSION

  local selected_major_version
  selected_major_version="$(
    sed -n 's/^Xcode \([0-9][0-9]*\).*/\1/p' \
      <<<"${MOJO_IOS_SELECTED_XCODE_VERSION}" | head -n 1
  )"
  [[ "${selected_major_version}" =~ ^[0-9]+$ ]] || \
    mojo_ios_tooling_error \
      "could not parse Xcode version from: ${MOJO_IOS_SELECTED_XCODE_VERSION}" || \
    return 1
  (( selected_major_version >= 27 )) || \
    mojo_ios_tooling_error \
      "Xcode 27 or newer is required; selected ${MOJO_IOS_SELECTED_XCODE_VERSION//$'\n'/, }" || \
    return 1

  MOJO_IOS_SELECTED_XCODE_MAJOR="${selected_major_version}"
  export MOJO_IOS_SELECTED_XCODE_MAJOR
}

mojo_ios_discover_metal_frontend() {
  [[ -n "${DEVELOPER_DIR:-}" ]] || \
    mojo_ios_tooling_error "select an Apple toolchain before discovering Metal" || \
    return 1

  local metal_component
  metal_component="$(xcodebuild -showComponent MetalToolchain -json)" || {
    mojo_ios_tooling_error \
      "Metal component metadata query failed for ${DEVELOPER_DIR}; this does not prove Metal is absent"
    return 1
  }

  local metal_status
  metal_status="$(plutil -extract status raw - <<<"${metal_component}")" || {
    mojo_ios_tooling_error "Metal component metadata has no status field"
    return 1
  }
  [[ "${metal_status}" = "installed" ]] || {
    mojo_ios_tooling_error \
      "Metal component reports status=${metal_status}; install it in Xcode Settings"
    return 1
  }

  local metal_search_path
  metal_search_path="$(
    plutil -extract toolchainSearchPath raw - <<<"${metal_component}"
  )" || {
    mojo_ios_tooling_error \
      "installed Metal component metadata has no toolchainSearchPath"
    return 1
  }

  local metal_frontend="${metal_search_path}/Metal.xctoolchain/usr/bin/metal"
  [[ -x "${metal_frontend}" ]] || {
    mojo_ios_tooling_error \
      "Metal component is installed but its frontend is not executable: ${metal_frontend}"
    return 1
  }

  local metal_version
  metal_version="$("${metal_frontend}" --version)" || {
    mojo_ios_tooling_error \
      "Metal frontend exists but could not run: ${metal_frontend}"
    return 1
  }

  MOJO_IOS_METAL_FRONTEND="${metal_frontend}"
  MOJO_IOS_METAL_VERSION="${metal_version}"
  export MOJO_IOS_METAL_FRONTEND MOJO_IOS_METAL_VERSION
}
