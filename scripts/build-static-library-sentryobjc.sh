#!/bin/bash
#
# Builds a single SentryObjC static library slice via SPM.
#
# Archives the SentryObjC SPM scheme for a given SDK and merges its target
# objects, including their full DWARF debug information, into libSentryObjC.a.

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
    DEBUG_INFORMATION_FORMAT=dwarf \
    CLANG_ENABLE_MODULE_DEBUGGING=NO \
    OTHER_SWIFT_FLAGS="-Xfrontend -no-clang-module-breadcrumbs" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    ENABLE_CODE_COVERAGE=NO \
    2>&1 | tee "$ARCHIVE_DIR/$SDK.log" | xcbeautify --preserve-unbeautified
end_group

link_file_list_root="$DERIVED_DATA/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/IntermediateBuildFilesPath"
architectures=()
while IFS= read -r -d '' link_file_list; do
    architecture="$(basename "$(dirname "$link_file_list")")"
    if [ ${#architectures[@]} -eq 0 ] || [[ " ${architectures[*]} " != *" $architecture "* ]]; then
        architectures+=( "$architecture" )
    fi
done < <(find "$link_file_list_root" -type f -name "*.LinkFileList" -print0)

if [ ${#architectures[@]} -eq 0 ]; then
    log_error "No link file lists found under $link_file_list_root"
    exit 1
fi

archive_dir="$LIB_DIR/$SDK"
thin_archive_dir="$archive_dir/thin-archives"
static_lib="$archive_dir/libSentryObjC.a"
rm -rf "$thin_archive_dir"
mkdir -p "$thin_archive_dir"

thin_archives=()
for architecture in "${architectures[@]}"; do
    object_file_list="$thin_archive_dir/$architecture.filelist"
    object_dir="$thin_archive_dir/$architecture-objects"
    : > "$object_file_list"
    mkdir -p "$object_dir"

    object_count=0
    while IFS= read -r -d '' link_file_list; do
        target_build_dir="$(dirname "$(dirname "$(dirname "$link_file_list")")")"
        target_name="$(basename "$target_build_dir" .build)"
        while IFS= read -r object; do
            if [ ! -f "$object" ]; then
                log_error "Object file not found: $object"
                exit 1
            fi

            staged_object="$object_dir/$target_name-${object##*/}"
            if [ -e "$staged_object" ]; then
                log_error "Duplicate object file name in $target_name: ${object##*/}"
                exit 1
            fi
            cp "$object" "$staged_object"
            printf '%s\n' "$staged_object" >> "$object_file_list"
            object_count=$((object_count + 1))
        done < "$link_file_list"
    done < <(find "$link_file_list_root" \
        -path "*/Objects-normal/$architecture/*.LinkFileList" -type f -print0)

    if [ "$object_count" -eq 0 ]; then
        log_error "No object files found for $architecture"
        exit 1
    fi

    thin_archive="$thin_archive_dir/libSentryObjC-$architecture.a"
    begin_group "Create $architecture static library for $SDK"
    log_info "  Objects: $object_count files"
    log_info "  Output:  $thin_archive"
    libtool -static -no_warning_for_no_symbols \
        -filelist "$object_file_list" \
        -o "$thin_archive"
    end_group
    thin_archives+=( "$thin_archive" )
done

begin_group "Create universal static library for $SDK"
log_info "  Architectures: ${architectures[*]}"
log_info "  Output:        $static_lib"
lipo -create "${thin_archives[@]}" -output "$static_lib"
end_group

rm -rf "$thin_archive_dir"
log_info "Static slice with full DWARF built: $static_lib"
