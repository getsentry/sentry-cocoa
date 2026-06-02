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

SDK=""
STATIC_LIB=""
HEADERS_DIR=""
OUTPUT_DIR="XCFrameworkBuildPath"
FRAMEWORK_NAME="SentryObjC"

usage() {
    log_notice "Usage: $0"
    log_notice "  --sdk <name>              Target SDK, e.g. iphoneos, iphonesimulator, macosx (required)"
    log_notice "  --static-lib <path>       Path to libSentryObjC.a (required)"
    log_notice "  --headers <path>          Path to public headers directory (required)"
    log_notice "  --output-dir <path>       Output directory (default: XCFrameworkBuildPath)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sdk)         SDK="$2";         shift 2 ;;
        --static-lib)  STATIC_LIB="$2";  shift 2 ;;
        --headers)     HEADERS_DIR="$2";  shift 2 ;;
        --output-dir)  OUTPUT_DIR="$2";   shift 2 ;;
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

SYSTEM_LIBS=( z c++ )
REQUIRED_FRAMEWORKS=( Foundation CoreData CoreGraphics QuartzCore )
CANDIDATE_WEAK_FRAMEWORKS=( SystemConfiguration AVFoundation CoreMedia CoreVideo MetricKit PDFKit SwiftUI UIKit WebKit AppKit )

arch_targets_for_sdk() {
    case "$1" in
        iphoneos)          echo "arm64-apple-ios15.0" ;;
        iphonesimulator)   echo "arm64-apple-ios15.0-simulator x86_64-apple-ios15.0-simulator" ;;
        macosx)            echo "arm64-apple-macos10.14 x86_64-apple-macos10.14" ;;
        maccatalyst)       echo "arm64-apple-ios15.0-macabi x86_64-apple-ios15.0-macabi" ;;
        appletvos)         echo "arm64-apple-tvos15.0" ;;
        appletvsimulator)  echo "arm64-apple-tvos15.0-simulator x86_64-apple-tvos15.0-simulator" ;;
        watchos)           echo "arm64-apple-watchos8.0 arm64_32-apple-watchos8.0 armv7k-apple-watchos8.0" ;;
        watchsimulator)    echo "arm64-apple-watchos8.0-simulator x86_64-apple-watchos8.0-simulator" ;;
        xros)              echo "arm64-apple-xros1.0" ;;
        xrsimulator)       echo "arm64-apple-xros1.0-simulator" ;;
        *)                 log_error "Unknown SDK: $1"; exit 1 ;;
    esac
}

is_macos_layout() {
    [ "$1" = "macosx" ] || [ "$1" = "maccatalyst" ]
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
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
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
linker_flags+=( -Xlinker -compatibility_version -Xlinker 1.0.0 )
linker_flags+=( -Xlinker -current_version -Xlinker 1.0.0 )
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
trap 'rm -f "$dummy_swift" /tmp/SentryObjC_"${SDK}"_*' EXIT

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

end_group

log_info "Dynamic slice $SDK built: $FW_DIR"
log_info "  Binary size: $(du -h "$binary_path" | cut -f1)"
