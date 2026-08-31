cmake_minimum_required(VERSION 3.30)

project(MojoIOSReferenceApp VERSION 0.1.0 LANGUAGES Swift)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "MojoIOSReferenceApp must be configured for iOS")
endif()

if(NOT DEFINED MOJO_IOS_DEVELOPMENT_TEAM OR
   MOJO_IOS_DEVELOPMENT_TEAM STREQUAL "")
  message(FATAL_ERROR "MOJO_IOS_DEVELOPMENT_TEAM is required")
endif()

if(NOT DEFINED MOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER OR
   MOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER STREQUAL "")
  message(FATAL_ERROR "MOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER is required")
endif()

set(mojo_ios_project_root "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(mojo_ios_reference_assets "${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets")
set(mojo_ios_reference_library
    "${mojo_ios_project_root}/build/MojoIOSReference.xcframework/ios-arm64/libMojoIOSReference.a")
if(NOT EXISTS "${mojo_ios_reference_library}")
  message(FATAL_ERROR
          "Missing reference-app library: ${mojo_ios_reference_library}")
endif()

add_executable(
  MojoIOSReferenceApp
  MACOSX_BUNDLE
    ReferenceApp.swift
    "${mojo_ios_reference_assets}"
)

set_source_files_properties(
  "${mojo_ios_reference_assets}"
  PROPERTIES MACOSX_PACKAGE_LOCATION Resources
)

target_include_directories(
  MojoIOSReferenceApp
  PRIVATE "${mojo_ios_project_root}/include"
)

target_link_libraries(
  MojoIOSReferenceApp
  PRIVATE
    "${mojo_ios_reference_library}"
    "-framework Foundation"
    "-framework Metal"
    "-framework UIKit"
)

target_link_options(MojoIOSReferenceApp PRIVATE "LINKER:-dead_strip")

set_target_properties(
  MojoIOSReferenceApp
  PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER "${MOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER}"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION "1"
    XCODE_ATTRIBUTE_DEAD_CODE_STRIPPING "YES"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${MOJO_IOS_DEVELOPMENT_TEAM}"
    XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "NO"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
    XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
    XCODE_ATTRIBUTE_MARKETING_VERSION "0.1.0"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER
      "${MOJO_IOS_REFERENCE_BUNDLE_IDENTIFIER}"
    XCODE_ATTRIBUTE_SKIP_INSTALL "NO"
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos"
    XCODE_ATTRIBUTE_SWIFT_VERSION "6.0"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
)

install(TARGETS MojoIOSReferenceApp BUNDLE DESTINATION .)
