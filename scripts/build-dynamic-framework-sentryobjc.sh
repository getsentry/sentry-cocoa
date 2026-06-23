#!/bin/bash
#
# Builds a single SentryObjC dynamic framework slice from a static library.
#
# Takes a pre-built libSentryObjC.a (from build-static-library-sentryobjc.sh)
# and re-links it as a dynamic library via swiftc, then packages the result
# as a .framework bundle with headers and a modulemap.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./tools.sh disable=SC1091
source "$SCRIPT_DIR/tools.sh"

SDK=""
STATIC_LIB=""
HEADERS_DIR=""
OUTPUT_DIR="XCFrameworkBuildPath"
FRAMEWORK_NAME="SentryObjC"
VERSION=""

usage() {
    log_notice "Usage: $0"
    log_notice "  --sdk <name>              Target SDK, e.g. iphoneos, iphonesimulator, macosx (required)"
    log_notice "  --static-lib <path>       Path to libSentryObjC.a (required)"
    log_notice "  --headers <path>          Path to public headers directory (required)"
    log_notice "  --output-dir <path>       Output directory (default: XCFrameworkBuildPath)"
    log_notice "  --version <semver>        Version string for the framework (default: 0.0.0)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sdk)         SDK="$2";         shift 2 ;;
        --static-lib)  STATIC_LIB="$2";  shift 2 ;;
        --headers)     HEADERS_DIR="$2";  shift 2 ;;
        --output-dir)  OUTPUT_DIR="$2";   shift 2 ;;
        --version)     VERSION="$2";      shift 2 ;;
        -h|--help)     usage ;;
        *)             log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$SDK" ]; then
    log_error "Error: --sdk is required"
    usage
fi
if [ -z "$STATIC_LIB" ]; then
    log_error "Error: --static-lib is required"
    usage
fi
if [ ! -f "$STATIC_LIB" ]; then
    log_error "Static library not found: $STATIC_LIB"
    exit 1
fi
if [ -z "$HEADERS_DIR" ]; then
    log_error "Error: --headers is required"
    usage
fi
if [ ! -d "$HEADERS_DIR" ]; then
    log_error "Headers directory not found: $HEADERS_DIR"
    exit 1
fi

if [ -z "$VERSION" ]; then
    version_xcconfig="$SCRIPT_DIR/../Sources/Configuration/Versioning.xcconfig"
    if [ -f "$version_xcconfig" ]; then
        VERSION="$(read_xcconfig_value --key MARKETING_VERSION --file "$version_xcconfig")"
    fi
fi
if [ -z "$VERSION" ]; then
    log_error "Error: could not determine version. Pass --version or ensure Versioning.xcconfig exists."
    exit 1
fi
BUNDLE_SHORT_VERSION="${VERSION%%+*}"
BUNDLE_VERSION="${BUNDLE_SHORT_VERSION%%-*}"

deployment_targets_xcconfig="$SCRIPT_DIR/../Sources/Configuration/DeploymentTargets.xcconfig"
if [ ! -f "$deployment_targets_xcconfig" ]; then
    log_error "DeploymentTargets.xcconfig not found at $deployment_targets_xcconfig"
    exit 1
fi

DT_IOS="$(read_xcconfig_value_or_exit --key IPHONEOS_DEPLOYMENT_TARGET --file "$deployment_targets_xcconfig")"
DT_MACOS="$(read_xcconfig_value_or_exit --key MACOSX_DEPLOYMENT_TARGET --file "$deployment_targets_xcconfig")"
DT_TVOS="$(read_xcconfig_value_or_exit --key TVOS_DEPLOYMENT_TARGET --file "$deployment_targets_xcconfig")"
DT_WATCHOS="$(read_xcconfig_value_or_exit --key WATCHOS_DEPLOYMENT_TARGET --file "$deployment_targets_xcconfig")"
DT_XROS="$(read_xcconfig_value_or_exit --key XROS_DEPLOYMENT_TARGET --file "$deployment_targets_xcconfig")"

SYSTEM_LIBS=( z c++ )
REQUIRED_FRAMEWORKS=( Foundation CoreData CoreGraphics QuartzCore )
CANDIDATE_WEAK_FRAMEWORKS=( SystemConfiguration AVFoundation CoreMedia CoreVideo MetricKit PDFKit SwiftUI UIKit WebKit AppKit )

arch_targets_for_sdk() {
    case "$1" in
        iphoneos)          echo "arm64-apple-ios${DT_IOS}" ;;
        iphonesimulator)   echo "arm64-apple-ios${DT_IOS}-simulator x86_64-apple-ios${DT_IOS}-simulator" ;;
        macosx)            echo "arm64-apple-macos${DT_MACOS} x86_64-apple-macos${DT_MACOS}" ;;
        maccatalyst)       echo "arm64-apple-ios${DT_IOS}-macabi x86_64-apple-ios${DT_IOS}-macabi" ;;
        appletvos)         echo "arm64-apple-tvos${DT_TVOS}" ;;
        appletvsimulator)  echo "arm64-apple-tvos${DT_TVOS}-simulator x86_64-apple-tvos${DT_TVOS}-simulator" ;;
        watchos)           echo "arm64-apple-watchos${DT_WATCHOS} arm64_32-apple-watchos${DT_WATCHOS} armv7k-apple-watchos${DT_WATCHOS}" ;;
        watchsimulator)    echo "arm64-apple-watchos${DT_WATCHOS}-simulator x86_64-apple-watchos${DT_WATCHOS}-simulator" ;;
        xros)              echo "arm64-apple-xros${DT_XROS}" ;;
        xrsimulator)       echo "arm64-apple-xros${DT_XROS}-simulator" ;;
        *)                 log_error "Unknown SDK: $1"; exit 1 ;;
    esac
}

is_macos_layout() {
    [ "$1" = "macosx" ] || [ "$1" = "maccatalyst" ]
}

minimum_os_version_for_sdk() {
    case "$1" in
        iphoneos|iphonesimulator|maccatalyst)  echo "$DT_IOS" ;;
        macosx)                                echo "$DT_MACOS" ;;
        appletvos|appletvsimulator)            echo "$DT_TVOS" ;;
        watchos|watchsimulator)                echo "$DT_WATCHOS" ;;
        xros|xrsimulator)                      echo "$DT_XROS" ;;
        *)                                     log_error "Unknown SDK: $1"; exit 1 ;;
    esac
}

supported_platforms_for_sdk() {
    case "$1" in
        iphoneos)          echo "iPhoneOS" ;;
        iphonesimulator)   echo "iPhoneSimulator" ;;
        macosx)            echo "MacOSX" ;;
        maccatalyst)       echo "MacOSX" ;;
        appletvos)         echo "AppleTVOS" ;;
        appletvsimulator)  echo "AppleTVSimulator" ;;
        watchos)           echo "WatchOS" ;;
        watchsimulator)    echo "WatchSimulator" ;;
        xros)              echo "XROS" ;;
        xrsimulator)       echo "XRSimulator" ;;
        *)                 log_error "Unknown SDK: $1"; exit 1 ;;
    esac
}

FW_DIR="$OUTPUT_DIR/framework/$FRAMEWORK_NAME/$SDK/$FRAMEWORK_NAME.framework"
rm -rf "$FW_DIR"

begin_group "Build $FRAMEWORK_NAME.framework for $SDK"

# --- Create framework structure ---
if is_macos_layout "$SDK"; then
    versioned="$FW_DIR/Versions/A"
    mkdir -p "$versioned/Headers" "$versioned/Modules" "$versioned/Resources"
    cp -R "$HEADERS_DIR"/. "$versioned/Headers/"
    ln -sfh A "$FW_DIR/Versions/Current"
    ln -sfh Versions/Current/Headers "$FW_DIR/Headers"
    ln -sfh Versions/Current/Modules "$FW_DIR/Modules"
    ln -sfh Versions/Current/Resources "$FW_DIR/Resources"
    ln -sfh "Versions/Current/$FRAMEWORK_NAME" "$FW_DIR/$FRAMEWORK_NAME"
    modules_dir="$versioned/Modules"
    binary_path="$versioned/$FRAMEWORK_NAME"
    resources_dir="$versioned/Resources"
else
    mkdir -p "$FW_DIR/Headers" "$FW_DIR/Modules"
    cp -R "$HEADERS_DIR"/. "$FW_DIR/Headers/"
    modules_dir="$FW_DIR/Modules"
    binary_path="$FW_DIR/$FRAMEWORK_NAME"
    resources_dir="$FW_DIR"
fi

cat > "$modules_dir/module.modulemap" <<EOF
framework module $FRAMEWORK_NAME {
  umbrella header "$FRAMEWORK_NAME.h"
  export *
  module * { export * }
}
EOF

MIN_OS_VERSION="$(minimum_os_version_for_sdk "$SDK")"
SUPPORTED_PLATFORM="$(supported_platforms_for_sdk "$SDK")"

cat > "$resources_dir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$FRAMEWORK_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>io.sentry.$FRAMEWORK_NAME</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$FRAMEWORK_NAME</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>$BUNDLE_SHORT_VERSION</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>$SUPPORTED_PLATFORM</string>
  </array>
  <key>CFBundleVersion</key>
  <string>$BUNDLE_VERSION</string>
  <key>MinimumOSVersion</key>
  <string>$MIN_OS_VERSION</string>
</dict>
</plist>
EOF

# --- Resolve SDK paths and framework dependencies ---
if [ "$SDK" = "maccatalyst" ]; then
    sysroot="$(xcrun --sdk macosx --show-sdk-path)"
else
    sysroot="$(xcrun --sdk "$SDK" --show-sdk-path)"
fi

fw_search_path="$sysroot/System/Library/Frameworks"
catalyst_fw_path=""
if [ "$SDK" = "maccatalyst" ]; then
    catalyst_fw_path="$sysroot/System/iOSSupport/System/Library/Frameworks"
fi

weak_frameworks=()
for fw in "${CANDIDATE_WEAK_FRAMEWORKS[@]}"; do
    if [ -d "$fw_search_path/$fw.framework" ]; then
        weak_frameworks+=( "$fw" )
    elif [ "$SDK" = "maccatalyst" ] && [ -n "$catalyst_fw_path" ] && [ -d "$catalyst_fw_path/$fw.framework" ]; then
        weak_frameworks+=( "$fw" )
    fi
done

log_info "  SDK:             $SDK"
log_info "  Static lib:      $STATIC_LIB"
log_info "  Weak frameworks: ${weak_frameworks[*]}"

# --- Build linker flags ---
linker_flags=()
linker_flags+=( -Xlinker -install_name -Xlinker "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" )
linker_flags+=( -Xlinker -rpath -Xlinker "@executable_path/Frameworks" )
linker_flags+=( -Xlinker -force_load -Xlinker "$STATIC_LIB" )
linker_flags+=( -Xlinker -compatibility_version -Xlinker "$BUNDLE_VERSION" )
linker_flags+=( -Xlinker -current_version -Xlinker "$BUNDLE_VERSION" )
if [ "$SDK" = "maccatalyst" ]; then
    linker_flags+=( -Xlinker -F -Xlinker "$catalyst_fw_path" )
fi
for fw in "${REQUIRED_FRAMEWORKS[@]}"; do
    linker_flags+=( -framework "$fw" )
done
for fw in "${weak_frameworks[@]}"; do
    linker_flags+=( -Xlinker -weak_framework -Xlinker "$fw" )
done
for lib in "${SYSTEM_LIBS[@]}"; do
    linker_flags+=( -l"$lib" )
done

# --- Link per architecture ---
read -r -a arch_targets <<< "$(arch_targets_for_sdk "$SDK")"
dummy_swift="$(mktemp /tmp/SentryObjC_dummy_XXXXXX.swift)"
echo "" > "$dummy_swift"
# shellcheck disable=SC2064
trap "rm -f '$dummy_swift' /tmp/SentryObjC_${SDK}_*" EXIT

arch_binaries=()
for target in "${arch_targets[@]}"; do
    arch="${target%%-*}"
    log_info "  Linking arch: $arch ($target)"

    arch_output="/tmp/SentryObjC_${SDK}_${arch}"
    xcrun swiftc \
        "$dummy_swift" \
        -emit-library \
        -target "$target" \
        -sdk "$sysroot" \
        "${linker_flags[@]}" \
        -o "$arch_output"
    arch_binaries+=( "$arch_output" )
done

# --- Create universal binary ---
if [ "${#arch_binaries[@]}" -gt 1 ]; then
    xcrun lipo -create "${arch_binaries[@]}" -output "$binary_path"
else
    cp "${arch_binaries[0]}" "$binary_path"
fi

dsym_path="$OUTPUT_DIR/framework/$FRAMEWORK_NAME/$SDK/$FRAMEWORK_NAME.framework.dSYM"
log_info "  Generating dSYM: $dsym_path"
xcrun dsymutil "$binary_path" -o "$dsym_path"

log_info "  Stripping debug symbols from binary"
xcrun strip -x "$binary_path"

end_group

log_info "Dynamic slice $SDK built: $FW_DIR"
log_info "  Binary size: $(du -h "$binary_path" | cut -f1)"
