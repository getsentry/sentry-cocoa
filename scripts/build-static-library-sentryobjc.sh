#!/bin/bash
#
# Builds a single SentryObjC static library slice via SPM.
#
# Archives the SentryObjC SPM scheme for a given SDK, collects the per-target
# object files, and merges them with libtool into a single libSentryObjC.a.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SDK=""
OUTPUT_DIR="XCFrameworkBuildPath"
PACKAGE_PATH=""
CONFIGURATION="Release"

usage() {
    log_notice "Usage: $0"
    log_notice "  --sdk <name>              Target SDK, e.g. iphoneos, iphonesimulator, macosx (required)"
    log_notice "  --output-dir <path>       Output directory (default: XCFrameworkBuildPath)"
    log_notice "  --package-path <path>     Swift Package root (default: repo root)"
    log_notice "  --configuration <name>    Xcode configuration (default: Release)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sdk)            SDK="$2";            shift 2 ;;
        --output-dir)     OUTPUT_DIR="$2";     shift 2 ;;
        --package-path)   PACKAGE_PATH="$2";   shift 2 ;;
        --configuration)  CONFIGURATION="$2";  shift 2 ;;
        -h|--help)        usage ;;
        *)                log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$SDK" ]; then
    log_error "Error: --sdk is required"
    usage
fi

if [ -z "$PACKAGE_PATH" ]; then
    PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [ ! -f "$PACKAGE_PATH/Package.swift" ]; then
    log_error "Package.swift not found at $PACKAGE_PATH"
    exit 1
fi

SCHEME="SentryObjC"
ARCHIVE_DIR="$OUTPUT_DIR/archive/$SCHEME"
DERIVED_DATA="$OUTPUT_DIR/DerivedData"
LIB_DIR="$OUTPUT_DIR/lib/$SCHEME"

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

destination="$(destination_for_sdk "$SDK")"
archive_path="$ARCHIVE_DIR/$SDK.xcarchive"

mkdir -p "$ARCHIVE_DIR" "$LIB_DIR"

begin_group "Archive $SCHEME for $SDK"
log_info "  SDK:            $SDK"
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
    2>&1 | tee "$ARCHIVE_DIR/$SDK.log" | xcbeautify --preserve-unbeautified
end_group

objects=()
while IFS= read -r -d '' obj; do
    objects+=( "$obj" )
done < <(find "$archive_path/Products" -type f -name "*.o" -print0)

if [ ${#objects[@]} -eq 0 ]; then
    log_error "No object files found under $archive_path/Products"
    exit 1
fi

static_lib="$LIB_DIR/$SDK/libSentryObjC.a"
mkdir -p "$(dirname "$static_lib")"

begin_group "Create static library for $SDK"
log_info "  Objects: ${#objects[@]} files"
log_info "  Output:  $static_lib"
libtool -static -o "$static_lib" "${objects[@]}"
end_group

log_info "Slice $SDK built: $static_lib"
