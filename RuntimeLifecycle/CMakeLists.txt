cmake_minimum_required(VERSION 3.30)

project(MojoIOSRuntimeLifecycle VERSION 0.1.0 LANGUAGES Swift)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "MojoIOSRuntimeLifecycle must be configured for iOS")
endif()
foreach(required_variable
        MOJO_IOS_LIFECYCLE_LIBRARY_A
        MOJO_IOS_LIFECYCLE_LIBRARY_B
        MOJO_IOS_LIFECYCLE_HARNESS
        MOJO_IOS_LIFECYCLE_OPTIMIZATION
        MOJO_IOS_LIFECYCLE_LINK_ORDER)
  if(NOT DEFINED ${required_variable})
    message(FATAL_ERROR "${required_variable} is required")
  endif()
endforeach()
foreach(required_path
        "${MOJO_IOS_LIFECYCLE_LIBRARY_A}"
        "${MOJO_IOS_LIFECYCLE_LIBRARY_B}"
        "${MOJO_IOS_LIFECYCLE_HARNESS}")
  if(NOT EXISTS "${required_path}")
    message(FATAL_ERROR "Missing runtime lifecycle input: ${required_path}")
  endif()
endforeach()
if(NOT MOJO_IOS_LIFECYCLE_LINK_ORDER STREQUAL "ab" AND
   NOT MOJO_IOS_LIFECYCLE_LINK_ORDER STREQUAL "ba")
  message(FATAL_ERROR "MOJO_IOS_LIFECYCLE_LINK_ORDER must be ab or ba")
endif()

add_executable(
  MojoIOSRuntimeLifecycle
  MACOSX_BUNDLE
  RuntimeLifecycleApp.swift
)

target_compile_definitions(
  MojoIOSRuntimeLifecycle
  PRIVATE
  MOJO_IOS_LIFECYCLE_O${MOJO_IOS_LIFECYCLE_OPTIMIZATION}
  MOJO_IOS_LIFECYCLE_LINK_ORDER_${MOJO_IOS_LIFECYCLE_LINK_ORDER}
)

if(MOJO_IOS_LIFECYCLE_LINK_ORDER STREQUAL "ab")
  set(mojo_ios_first_library "${MOJO_IOS_LIFECYCLE_LIBRARY_A}")
  set(mojo_ios_second_library "${MOJO_IOS_LIFECYCLE_LIBRARY_B}")
else()
  set(mojo_ios_first_library "${MOJO_IOS_LIFECYCLE_LIBRARY_B}")
  set(mojo_ios_second_library "${MOJO_IOS_LIFECYCLE_LIBRARY_A}")
endif()

target_link_libraries(
  MojoIOSRuntimeLifecycle
  PRIVATE
  "${MOJO_IOS_LIFECYCLE_HARNESS}"
  "${mojo_ios_first_library}"
  "${mojo_ios_second_library}"
  "-framework UIKit"
)

if(DEFINED MOJO_IOS_DEVELOPMENT_TEAM AND
   NOT MOJO_IOS_DEVELOPMENT_TEAM STREQUAL "")
  set(mojo_ios_code_sign_style "Automatic")
else()
  set(mojo_ios_code_sign_style "Manual")
endif()

set(mojo_ios_bundle_identifier
    "com.ianhorn.mojoios.runtimelifecycle.${MOJO_IOS_LIFECYCLE_LINK_ORDER}.o${MOJO_IOS_LIFECYCLE_OPTIMIZATION}")
set_target_properties(
  MojoIOSRuntimeLifecycle
  PROPERTIES
  MACOSX_BUNDLE_GUI_IDENTIFIER "${mojo_ios_bundle_identifier}"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
  XCODE_ATTRIBUTE_CODE_SIGN_STYLE "${mojo_ios_code_sign_style}"
  XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${MOJO_IOS_DEVELOPMENT_TEAM}"
  XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "NO"
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${mojo_ios_bundle_identifier}"
  XCODE_ATTRIBUTE_SWIFT_VERSION "6.0"
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
)
