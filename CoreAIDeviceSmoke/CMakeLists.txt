cmake_minimum_required(VERSION 3.30)

project(MojoIOSCoreAIDeviceSmoke VERSION 0.1.0 LANGUAGES Swift)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "MojoIOSCoreAIDeviceSmoke must be configured for iOS")
endif()

set(mojo_ios_project_root "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(mojo_ios_coreai_asset
    "${mojo_ios_project_root}/build/coreai-mvp/CoreAIMatmulMatmulF32.aimodel")

if(NOT IS_DIRECTORY "${mojo_ios_coreai_asset}")
  message(FATAL_ERROR
          "Missing Core AI asset; run build-coreai-mvp-resources first: ${mojo_ios_coreai_asset}")
endif()
add_executable(
  MojoIOSCoreAIDeviceSmoke MACOSX_BUNDLE
  CoreAIDeviceSmokeApp.swift
  "${mojo_ios_coreai_asset}"
)

set_source_files_properties(
  "${mojo_ios_coreai_asset}"
  PROPERTIES MACOSX_PACKAGE_LOCATION Resources
)

target_link_libraries(
  MojoIOSCoreAIDeviceSmoke
  PRIVATE
    "-framework CoreAI"
    "-framework Foundation"
    "-framework UIKit"
)

set_target_properties(
  MojoIOSCoreAIDeviceSmoke
  PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.ianhorn.mojoios.coreai.devicesmoke"
    XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "YES"
    XCODE_ATTRIBUTE_INFOPLIST_KEY_UILaunchScreen_Generation "YES"
    XCODE_ATTRIBUTE_INFOPLIST_KEY_UISupportedInterfaceOrientations
      "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "27.0"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER
      "com.ianhorn.mojoios.coreai.devicesmoke"
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos"
    XCODE_ATTRIBUTE_SWIFT_VERSION "6.0"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
)

if(DEFINED MOJO_IOS_DEVELOPMENT_TEAM AND
   NOT MOJO_IOS_DEVELOPMENT_TEAM STREQUAL "")
  set_target_properties(
    MojoIOSCoreAIDeviceSmoke
    PROPERTIES
      XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
      XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${MOJO_IOS_DEVELOPMENT_TEAM}"
  )
else()
  set_target_properties(
    MojoIOSCoreAIDeviceSmoke
    PROPERTIES XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
  )
endif()
