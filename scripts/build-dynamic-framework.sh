#!/bin/bash
#
# Builds a single dynamic framework slice.
#
# Takes a pre-built static library (from build-static-library.sh)
# and re-links it as a dynamic library via swiftc, then packages the result
# as a .framework bundle with headers and optional prepared modules and resources.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./tools.sh disable=SC1091
source "$SCRIPT_DIR/tools.sh"

SDK=""
STATIC_LIB=""
HEADERS_DIR=""
OUTPUT_DIR=""
FRAMEWORK_NAME=""
MODULES_DIR=""
RESOURCES_DIR=""
VERSION=""

usage() {
    log_info "Usage: $0"
    log_info "  -d, --sdk <name>              Target SDK (required)"
    log_info "  -l, --static-lib <path>       Path to the static library (required)"
    log_info "  -H, --headers <path>          Path to public headers directory (required)"
    log_info "  -o, --output-dir <path>       Output directory (required)"
    log_info "  -v, --version <semver>        Framework version string (required)"
    log_info "  -n, --framework-name <name>   Framework/module name (required)"
    log_info "  -m, --modules <path>          Prepared modules directory, including an optional modulemap (optional)"
    log_info "  -r, --resources <path>        Prepared resources directory (optional)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ "$1" != -h && "$1" != --help ]] && [[ $# -lt 2 || "$2" == --* ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case $1 in
        -d|--sdk)         SDK="$2";         shift 2 ;;
        -l|--static-lib)  STATIC_LIB="$2";  shift 2 ;;
        -H|--headers)     HEADERS_DIR="$2";  shift 2 ;;
        -o|--output-dir)  OUTPUT_DIR="$2";   shift 2 ;;
        -v|--version)     VERSION="$2";      shift 2 ;;
        -n|--framework-name) FRAMEWORK_NAME="$2"; shift 2 ;;
        -m|--modules) MODULES_DIR="$2"; shift 2 ;;
        -r|--resources) RESOURCES_DIR="$2"; shift 2 ;;
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

if [ -z "$OUTPUT_DIR" ]; then
    log_error "--output-dir is required"
    usage
fi
if [ -z "$FRAMEWORK_NAME" ]; then
    log_error "--framework-name is required"
    usage
fi
if [ -z "$VERSION" ]; then
    log_error "--version is required"
    usage
fi

if [[ ! "$FRAMEWORK_NAME" =~ ^[A-Za-z_][A-Za-z_0-9]*$ ]]; then
    log_error "Invalid framework module name: $FRAMEWORK_NAME"
    exit 1
fi
if [ -n "$MODULES_DIR" ] && [ ! -d "$MODULES_DIR" ]; then
    log_error "Modules directory not found: $MODULES_DIR"
    exit 1
fi
if [ -n "$RESOURCES_DIR" ] && [ ! -d "$RESOURCES_DIR" ]; then
    log_error "Resources directory not found: $RESOURCES_DIR"
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
        watchos)           echo "arm64-apple-watchos${DT_WATCHOS} arm64_32-apple-watchos${DT_WATCHOS}" ;;
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
        iphoneos|iphonesimulator)              echo "$DT_IOS" ;;
        macosx|maccatalyst)                    echo "$DT_MACOS" ;;
        appletvos|appletvsimulator)            echo "$DT_TVOS" ;;
        watchos|watchsimulator)                echo "$DT_WATCHOS" ;;
        xros|xrsimulator)                      echo "$DT_XROS" ;;
        *)                                     log_error "Unknown SDK: $1"; exit 1 ;;
    esac
}

os_version_key_for_sdk() {
    if is_macos_layout "$1"; then
        echo "LSMinimumSystemVersion"
    else
        echo "MinimumOSVersion"
    fi
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
    # Homebrew coreutils can put GNU ln ahead of /bin/ln; it rejects -h, breaking framework packaging.
    # -n preserves the same no-dereference behavior on both GNU and BSD ln.
    ln -sfn A "$FW_DIR/Versions/Current"
    ln -sfn Versions/Current/Headers "$FW_DIR/Headers"
    ln -sfn Versions/Current/Modules "$FW_DIR/Modules"
    ln -sfn Versions/Current/Resources "$FW_DIR/Resources"
    ln -sfn "Versions/Current/$FRAMEWORK_NAME" "$FW_DIR/$FRAMEWORK_NAME"
    modules_dir="$versioned/Modules"
    binary_path="$versioned/$FRAMEWORK_NAME"
    resources_dir="$versioned/Resources"
else
    mkdir -p "$FW_DIR/Headers" "$FW_DIR/Modules"
    modules_dir="$FW_DIR/Modules"
    binary_path="$FW_DIR/$FRAMEWORK_NAME"
    resources_dir="$FW_DIR"
fi

# Prepared inputs are copied verbatim; product-specific transformations belong to the caller.
cp -R "$HEADERS_DIR"/. "$FW_DIR/Headers/"
if [ -n "$MODULES_DIR" ]; then
    cp -R "$MODULES_DIR"/. "$modules_dir/"
fi
if [ -n "$RESOURCES_DIR" ]; then
    cp -R "$RESOURCES_DIR"/. "$resources_dir/"
fi

# Preserve a supplied module map, or generate the existing headers-only framework module.
if [ ! -f "$modules_dir/module.modulemap" ]; then
    cat > "$modules_dir/module.modulemap" <<EOF
framework module $FRAMEWORK_NAME {
  umbrella header "$FRAMEWORK_NAME.h"
  export *
  module * { export * }
}
EOF
fi

MIN_OS_VERSION="$(minimum_os_version_for_sdk "$SDK")"
SUPPORTED_PLATFORM="$(supported_platforms_for_sdk "$SDK")"
OS_VERSION_KEY="$(os_version_key_for_sdk "$SDK")"

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
  <key>$OS_VERSION_KEY</key>
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
link_dir="$(mktemp -d "${TMPDIR:-/tmp}/$FRAMEWORK_NAME.XXXXXX")"
trap 'rm -rf "$link_dir"' EXIT
dummy_swift="$link_dir/empty.swift"
echo "" > "$dummy_swift"

arch_binaries=()
for target in "${arch_targets[@]}"; do
    arch="${target%%-*}"
    log_info "  Linking arch: $arch ($target)"

    arch_output="$link_dir/$arch"
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
