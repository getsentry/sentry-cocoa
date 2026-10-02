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
    log_info "Usage: $0"
    log_info "  --sdk <name>              Target SDK, e.g. iphoneos, iphonesimulator, macosx (required)"
    log_info "  --output-dir <path>       Output directory (default: XCFrameworkBuildPath)"
    log_info "  --package-path <path>     Swift Package root (default: repo root)"
    log_info "  --configuration <name>    Xcode configuration (default: Release)"
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

# Dependencies may archive extra legacy architectures that the Swift wrapper does not
# support. Distributing their union would advertise incomplete slices (e.g. armv7k).
# Use the wrapper's architecture set, but fail rather than silently omit a required slice.
wrapper_objects=()

for object in "${objects[@]}"; do
    if [ "${object##*/}" = "SentryObjCCompat.o" ]; then
        wrapper_objects+=( "$object" )
    fi
done

if [ "${#wrapper_objects[@]}" -ne 1 ]; then
    log_error "Expected one archived SentryObjCCompat.o, found ${#wrapper_objects[@]}"
    exit 1
fi

read -r -a wrapper_archs <<< "$(xcrun lipo -archs "${wrapper_objects[0]}")"
if [ "${#wrapper_archs[@]}" -eq 0 ]; then
    log_error "Could not read archived wrapper architectures"
    exit 1
fi

for object in "${objects[@]}"; do
    for arch in "${wrapper_archs[@]}"; do
        if ! xcrun lipo "$object" -verify_arch "$arch"; then
            log_error "Missing required wrapper architectures ($arch) in $object"
            exit 1
        fi
    done
done

log_info "  Distribution architectures: ${wrapper_archs[*]}"

archive_dir="$LIB_DIR/$SDK"
debug_static_lib="$archive_dir/libSentryObjC-Debug.a"
static_lib="$archive_dir/libSentryObjC.a"
stripped_objects_dir="$archive_dir/stripped-objects"
rm -rf "$stripped_objects_dir"
mkdir -p "$stripped_objects_dir"

architecture_libraries_dir="$archive_dir/architecture-libraries"
rm -rf "$architecture_libraries_dir"
mkdir -p "$architecture_libraries_dir"

create_static_library() {
    local output="$1"
    shift
    local architecture_libraries=()
    for arch in "${wrapper_archs[@]}"; do
        local library
        library="$architecture_libraries_dir/$(basename "$output")-$arch.a"
        libtool -static -arch_only "$arch" -no_warning_for_no_symbols -o "$library" "$@"
        architecture_libraries+=( "$library" )
    done
    xcrun lipo -create "${architecture_libraries[@]}" -output "$output"
}

begin_group "Create static libraries for $SDK"
log_info "  Objects:      ${#objects[@]} files"
log_info "  Debug output: $debug_static_lib"
# The dynamic framework build uses this unstripped archive to generate its separate dSYM.
# It is an intermediate and is not distributed as the static SentryObjC binary.
create_static_library "$debug_static_lib" "${objects[@]}"

stripped_objects=()
for object in "${objects[@]}"; do
    stripped_object="$stripped_objects_dir/${object##*/}"
    if [ -e "$stripped_object" ]; then
        log_error "Duplicate product object basename: ${object##*/}"
        exit 1
    fi
    cp "$object" "$stripped_object"
    # Remove STABS and DWARF debug-map entries that refer to producer-only CI paths, while
    # retaining all linkable content, including Objective-C categories without global symbols.
    if nm -arch all -ap "$stripped_object" 2> /dev/null | grep ' OSO ' > /dev/null; then
        strip -S "$stripped_object"
    fi
    stripped_objects+=( "$stripped_object" )
done

log_info "  Static output: $static_lib"
create_static_library "$static_lib" "${stripped_objects[@]}"
end_group

log_info "Static slice built: $static_lib"
log_info "Dynamic-linking intermediate built: $debug_static_lib"
