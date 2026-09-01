cmake_minimum_required(VERSION 3.30)

project(MojoIOSCPUConformance VERSION 0.1.0 LANGUAGES Swift)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "MojoIOSCPUConformance must be configured for iOS")
endif()
if(NOT DEFINED MOJO_IOS_CONFORMANCE_LIBRARY)
  message(FATAL_ERROR "MOJO_IOS_CONFORMANCE_LIBRARY is required")
endif()
if(NOT EXISTS "${MOJO_IOS_CONFORMANCE_LIBRARY}")
  message(FATAL_ERROR
          "Missing conformance library: ${MOJO_IOS_CONFORMANCE_LIBRARY}")
endif()
if(NOT DEFINED MOJO_IOS_CONFORMANCE_OPTIMIZATION)
  message(FATAL_ERROR "MOJO_IOS_CONFORMANCE_OPTIMIZATION is required")
endif()

add_executable(
  MojoIOSCPUConformance
  MACOSX_BUNDLE
  CPUConformanceApp.swift
)

target_compile_definitions(
  MojoIOSCPUConformance
  PRIVATE
  MOJO_IOS_CONFORMANCE_O${MOJO_IOS_CONFORMANCE_OPTIMIZATION}
)

target_link_libraries(
  MojoIOSCPUConformance
  PRIVATE
  "${MOJO_IOS_CONFORMANCE_LIBRARY}"
  "-framework UIKit"
)

if(DEFINED MOJO_IOS_DEVELOPMENT_TEAM AND
   NOT MOJO_IOS_DEVELOPMENT_TEAM STREQUAL "")
  set(mojo_ios_code_sign_style "Automatic")
else()
  set(mojo_ios_code_sign_style "Manual")
endif()

set_target_properties(
  MojoIOSCPUConformance
  PROPERTIES
  MACOSX_BUNDLE_GUI_IDENTIFIER
    "com.ianhorn.mojoios.cpuconformance.o${MOJO_IOS_CONFORMANCE_OPTIMIZATION}"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
  XCODE_ATTRIBUTE_CODE_SIGN_STYLE "${mojo_ios_code_sign_style}"
  XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${MOJO_IOS_DEVELOPMENT_TEAM}"
  XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "NO"
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER
    "com.ianhorn.mojoios.cpuconformance.o${MOJO_IOS_CONFORMANCE_OPTIMIZATION}"
  XCODE_ATTRIBUTE_SWIFT_VERSION "6.0"
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
)
