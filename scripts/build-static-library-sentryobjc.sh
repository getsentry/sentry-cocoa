#!/bin/bash
#
# Builds a single SentryObjC static library slice via SPM.
#
# Archives the SentryObjC SPM scheme for a given SDK and merges its target
# objects into two libraries: a stripped static distribution and an unstripped
# intermediate used to generate the dynamic framework dSYM.

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
while IFS= read -r -d '' object; do
    objects+=( "$object" )
done < <(find "$archive_path/Products" -type f -name "*.o" -print0)

if [ ${#objects[@]} -eq 0 ]; then
    log_error "No object files found under $archive_path/Products"
    exit 1
fi

archive_dir="$LIB_DIR/$SDK"
debug_static_lib="$archive_dir/libSentryObjC-Debug.a"
static_lib="$archive_dir/libSentryObjC.a"
stripped_objects_dir="$archive_dir/stripped-objects"
rm -rf "$stripped_objects_dir"
mkdir -p "$stripped_objects_dir"

begin_group "Create static libraries for $SDK"
log_info "  Objects:      ${#objects[@]} files"
log_info "  Debug output: $debug_static_lib"
# The dynamic framework build uses this unstripped archive to generate its separate dSYM.
# It is an intermediate and is not distributed as the static SentryObjC binary.
libtool -static -no_warning_for_no_symbols -o "$debug_static_lib" "${objects[@]}"

stripped_objects=()
for object in "${objects[@]}"; do
    # Simulator and Catalyst objects can contain multiple architectures. Keep the object if any
    # architecture defines a global symbol. `-gU` selects defined external symbols, while `-j`
    # prints only their names. `-arch all` also prints headings that must not count as symbols.
    if nm -arch all -gjU "$object" 2> /dev/null \
        | grep -v ' (for architecture .*):$' \
        | grep . > /dev/null; then
        stripped_object="$stripped_objects_dir/${object##*/}"
        if [ -e "$stripped_object" ]; then
            log_error "Duplicate product object basename: ${object##*/}"
            exit 1
        fi
        cp "$object" "$stripped_object"
        # Remove STABS and DWARF debug-map entries that refer to producer-only CI paths, while
        # retaining the symbols needed to link the static library into a consumer's product.
        strip -S "$stripped_object"
        stripped_objects+=( "$stripped_object" )
    fi
done

if [ ${#stripped_objects[@]} -eq 0 ]; then
    log_error "No object files with global symbols found under $archive_path/Products"
    exit 1
fi

log_info "  Static output: $static_lib"
libtool -static -no_warning_for_no_symbols -o "$static_lib" "${stripped_objects[@]}"
end_group

log_info "Static slice built: $static_lib"
log_info "Dynamic-linking intermediate built: $debug_static_lib"
