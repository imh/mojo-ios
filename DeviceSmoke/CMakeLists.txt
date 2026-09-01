cmake_minimum_required(VERSION 3.30)

project(MojoIOSDeviceSmoke VERSION 0.1.0 LANGUAGES Swift)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "MojoIOSDeviceSmoke must be configured for iOS")
endif()

if(NOT DEFINED MOJO_IOS_DEVELOPMENT_TEAM)
  message(FATAL_ERROR "MOJO_IOS_DEVELOPMENT_TEAM is required")
endif()

set(mojo_ios_project_root "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(mojo_ios_core_library
    "${mojo_ios_project_root}/build/MojoIOSCore.xcframework/ios-arm64/MojoIOSCore.framework/MojoIOSCore")

if(NOT EXISTS "${mojo_ios_core_library}")
  message(FATAL_ERROR "Missing device library: ${mojo_ios_core_library}")
endif()

add_executable(MojoIOSDeviceSmoke MACOSX_BUNDLE DeviceSmokeApp.swift)

target_include_directories(
  MojoIOSDeviceSmoke
  PRIVATE "${mojo_ios_project_root}/include"
)

if(MOJO_IOS_ENABLE_METAL_SMOKE)
  set(mojo_ios_metal_probe_object
      "${mojo_ios_project_root}/build/metal-gate/IOSMetalVectorAddProbe.o")
  if(NOT EXISTS "${mojo_ios_metal_probe_object}")
    message(FATAL_ERROR
            "Missing Metal probe object: ${mojo_ios_metal_probe_object}")
  endif()
  target_compile_definitions(
    MojoIOSDeviceSmoke PRIVATE MOJO_IOS_ENABLE_METAL_SMOKE
  )
  target_link_libraries(
    MojoIOSDeviceSmoke
    PRIVATE
      "${mojo_ios_metal_probe_object}"
      "-framework Foundation"
      "-framework Metal"
  )
endif()

target_link_libraries(
  MojoIOSDeviceSmoke
  PRIVATE
    "${mojo_ios_core_library}"
    "-framework UIKit"
)

set_target_properties(
  MojoIOSDeviceSmoke
  PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.ianhorn.mojoios.devicesmoke"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${MOJO_IOS_DEVELOPMENT_TEAM}"
    XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "YES"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.ianhorn.mojoios.devicesmoke"
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos"
    XCODE_ATTRIBUTE_SWIFT_VERSION "6.0"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
)
