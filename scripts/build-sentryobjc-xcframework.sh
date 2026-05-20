#!/bin/bash
#
# Builds an XCFramework from the SentryObjC Swift Package product.
#
# SentryObjC is an SPM library product without an explicit type, so
# `xcodebuild archive` emits a per-target Mach-O object file rather than a
# framework. For each SDK slice we archive, run libtool to bundle the
# SentryObjC + SentryObjCCompat objects into a static `libSentryObjC.a`,
# then combine the slices with `xcodebuild -create-xcframework -library`
# alongside the public ObjC headers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SCHEME="SentryObjC"
CONFIGURATION="Release"
OUTPUT_DIR="XCFrameworkBuildPath"
SDKS="iphoneos,iphonesimulator,macosx,maccatalyst,appletvos,appletvsimulator,watchos,watchsimulator,xros,xrsimulator"
PACKAGE_PATH=""

usage() {
    log_notice "Usage: $0"
    log_notice "  --output-dir <path>       Output directory (default: XCFrameworkBuildPath)"
    log_notice "  --configuration <name>    Xcode configuration (default: Release)"
    log_notice "  --sdks <list>             Comma-separated SDKs (default: all Apple SDKs)"
    log_notice "  --package-path <path>     Swift Package root (default: repo root containing Package.swift)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)      OUTPUT_DIR="$2";     shift 2 ;;
        --configuration)   CONFIGURATION="$2";  shift 2 ;;
        --sdks)            SDKS="$2";           shift 2 ;;
        --package-path)    PACKAGE_PATH="$2";   shift 2 ;;
        -h|--help)         usage ;;
        *)                 log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$PACKAGE_PATH" ]; then
    PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [ ! -f "$PACKAGE_PATH/Package.swift" ]; then
    log_error "Package.swift not found at $PACKAGE_PATH"
    exit 1
fi

ARCHIVE_DIR="$OUTPUT_DIR/archive/$SCHEME"
DERIVED_DATA="$OUTPUT_DIR/DerivedData"
LIB_DIR="$OUTPUT_DIR/lib/$SCHEME"
HEADERS_DIR="$PACKAGE_PATH/SentryObjC/include"
XCFRAMEWORK_PATH="$OUTPUT_DIR/$SCHEME.xcframework"

if [ ! -d "$HEADERS_DIR" ]; then
    log_error "Public headers directory not found at $HEADERS_DIR"
    exit 1
fi

rm -rf "$XCFRAMEWORK_PATH" "$ARCHIVE_DIR" "$DERIVED_DATA" "$LIB_DIR"
mkdir -p "$ARCHIVE_DIR" "$LIB_DIR"

# Map sdk → xcodebuild destination
destination_for_sdk() {
    case "$1" in
        iphoneos)           echo "generic/platform=iOS" ;;
        iphonesimulator)    echo "generic/platform=iOS Simulator" ;;
        macosx)             echo "generic/platform=macOS" ;;
        maccatalyst)        echo "generic/platform=macOS,variant=Mac Catalyst" ;;
        appletvos)          echo "generic/platform=tvOS" ;;
        appletvsimulator)   echo "generic/platform=tvOS Simulator" ;;
        watchos)            echo "generic/platform=watchOS" ;;
        watchsimulator)     echo "generic/platform=watchOS Simulator" ;;
        xros)               echo "generic/platform=visionOS" ;;
        xrsimulator)        echo "generic/platform=visionOS Simulator" ;;
        *)                  log_error "Unknown SDK: $1"; exit 1 ;;
    esac
}

IFS=',' read -r -a sdk_list <<< "$SDKS"

create_args=( -create-xcframework )

for sdk in "${sdk_list[@]}"; do
    destination="$(destination_for_sdk "$sdk")"
    archive_path="$ARCHIVE_DIR/$sdk.xcarchive"

    begin_group "Archive $SCHEME for $sdk"
    log_info "  Destination:    $destination"
    log_info "  Archive path:   $archive_path"

    set -o pipefail && NSUnbufferedIO=YES xcodebuild archive \
        -workspace "$PACKAGE_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$destination" \
        -archivePath "$archive_path" \
        -derivedDataPath "$DERIVED_DATA" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY= \
        ENABLE_CODE_COVERAGE=NO \
        2>&1 | tee "$ARCHIVE_DIR/$sdk.log" | xcbeautify --preserve-unbeautified
    end_group

    # SPM library products without an explicit type archive as per-target
    # Mach-O object files under Products/<user-home>/Objects/. Collect them
    # and merge into a single static library per slice.
    objects=()
    while IFS= read -r -d '' obj; do
        objects+=( "$obj" )
    done < <(find "$archive_path/Products" -type f -name "*.o" -print0)

    if [ ${#objects[@]} -eq 0 ]; then
        log_error "No object files found under $archive_path/Products"
        exit 1
    fi

    static_lib="$LIB_DIR/$sdk/lib$SCHEME.a"
    mkdir -p "$(dirname "$static_lib")"

    begin_group "Build static library for $sdk"
    log_info "  Objects:   ${objects[*]}"
    log_info "  Output:    $static_lib"
    libtool -static -o "$static_lib" "${objects[@]}"
    end_group

    create_args+=( -library "$static_lib" -headers "$HEADERS_DIR" )
done

create_args+=( -output "$XCFRAMEWORK_PATH" )

begin_group "Create $SCHEME.xcframework"
xcodebuild "${create_args[@]}"
end_group

log_info "Built $XCFRAMEWORK_PATH"
