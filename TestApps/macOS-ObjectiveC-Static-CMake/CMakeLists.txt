cmake_minimum_required(VERSION 3.24)

set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum macOS version")

project(macOS-ObjectiveC-Static-CMake LANGUAGES OBJC)
set(SENTRY_OBJC_STATIC_XCFRAMEWORK "" CACHE PATH
    "Path to an unpacked SentryObjC-Static.xcframework")

if(NOT SENTRY_OBJC_STATIC_XCFRAMEWORK)
    set(_sentry_version "9.27.0")
    set(_sentry_download_dir "${CMAKE_BINARY_DIR}/_downloads")
    set(_sentry_archive
        "${_sentry_download_dir}/SentryObjC-Static-${_sentry_version}.xcframework.zip")
    set(_sentry_extract_dir
        "${_sentry_download_dir}/SentryObjC-Static-${_sentry_version}")
    set(SENTRY_OBJC_STATIC_XCFRAMEWORK
        "${_sentry_extract_dir}/SentryObjC-Static.xcframework")

    if(NOT EXISTS "${SENTRY_OBJC_STATIC_XCFRAMEWORK}")
        file(MAKE_DIRECTORY "${_sentry_download_dir}" "${_sentry_extract_dir}")
        file(DOWNLOAD
            "https://github.com/getsentry/sentry-cocoa/releases/download/${_sentry_version}/SentryObjC-Static.xcframework.zip"
            "${_sentry_archive}"
            EXPECTED_HASH SHA256=2fc8c25afb25fed644e7f0bcf5689e5e3efa1e8a155799f6957ced5f7fc59940
            TLS_VERIFY ON
            SHOW_PROGRESS)
        file(ARCHIVE_EXTRACT
            INPUT "${_sentry_archive}"
            DESTINATION "${_sentry_extract_dir}")
    endif()
endif()

get_filename_component(
    SENTRY_OBJC_STATIC_XCFRAMEWORK
    "${SENTRY_OBJC_STATIC_XCFRAMEWORK}"
    ABSOLUTE)

set(_sentry_macos_slice
    "${SENTRY_OBJC_STATIC_XCFRAMEWORK}/macos-arm64_x86_64")
set(_sentry_library "${_sentry_macos_slice}/libSentryObjC.a")
set(_sentry_headers "${_sentry_macos_slice}/Headers")

if(NOT EXISTS "${_sentry_library}" OR NOT EXISTS "${_sentry_headers}")
    message(FATAL_ERROR
        "SENTRY_OBJC_STATIC_XCFRAMEWORK does not contain the macOS slice: "
        "${SENTRY_OBJC_STATIC_XCFRAMEWORK}")
endif()

execute_process(
    COMMAND xcrun --sdk macosx --show-sdk-path
    OUTPUT_VARIABLE _macos_sdk_path
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
execute_process(
    COMMAND xcrun --find swiftc
    OUTPUT_VARIABLE _swift_compiler
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
get_filename_component(_swift_bin_dir "${_swift_compiler}" DIRECTORY)
get_filename_component(_swift_usr_dir "${_swift_bin_dir}" DIRECTORY)

find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

add_executable(macOS-ObjectiveC-Static-CMake Sources/main.m)
target_include_directories(macOS-ObjectiveC-Static-CMake PRIVATE "${_sentry_headers}")
target_link_libraries(macOS-ObjectiveC-Static-CMake PRIVATE
    "${FOUNDATION_FRAMEWORK}"
    c++
    swiftCore)
target_link_options(macOS-ObjectiveC-Static-CMake PRIVATE
    "-L${_macos_sdk_path}/usr/lib/swift"
    "-L${_swift_usr_dir}/lib/swift/macosx"
    "LINKER:-force_load,${_sentry_library}")

set_target_properties(macOS-ObjectiveC-Static-CMake PROPERTIES
    XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
    XCODE_ATTRIBUTE_GCC_GENERATE_DEBUGGING_SYMBOLS "YES")
