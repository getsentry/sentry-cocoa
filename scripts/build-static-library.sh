#!/bin/bash
#
# Builds a single static library slice via SPM.
#
# Archives the selected SPM scheme for a given SDK and merges its target
# objects into two libraries: a stripped static distribution and an unstripped
# intermediate used to generate the dynamic framework dSYM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./tools.sh disable=SC1091
source "$SCRIPT_DIR/tools.sh"

SDK=""
OUTPUT_DIR=""
PACKAGE_PATH=""
CONFIGURATION=""
SCHEME=""
ARCHITECTURE_TARGET=""

usage() {
    log_info "Usage: $0"
    log_info "  -d, --sdk <name>                  Target SDK (required)"
    log_info "  -o, --output-dir <path>           Output directory (required)"
    log_info "  -p, --package-path <path>         Swift Package root (required)"
    log_info "  -c, --configuration <name>        Xcode configuration (required)"
    log_info "  -s, --scheme <name>               Package scheme and output library name (required)"
    log_info "  -a, --architecture-target <name>  Archived target whose architectures are required (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ "$1" != -h && "$1" != --help ]] && [[ $# -lt 2 || "$2" == --* ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case $1 in
        -d|--sdk)            SDK="$2";            shift 2 ;;
        -o|--output-dir)     OUTPUT_DIR="$2";     shift 2 ;;
        -p|--package-path)   PACKAGE_PATH="$2";   shift 2 ;;
        -c|--configuration)  CONFIGURATION="$2";  shift 2 ;;
        -s|--scheme)         SCHEME="$2";         shift 2 ;;
        -a|--architecture-target) ARCHITECTURE_TARGET="$2"; shift 2 ;;
        -h|--help)        usage ;;
        *)                log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$SDK" ]; then
    log_error "Error: --sdk is required"
    usage
fi

if [ -z "$OUTPUT_DIR" ]; then
    log_error "--output-dir is required"
    usage
fi
if [ -z "$PACKAGE_PATH" ]; then
    log_error "--package-path is required"
    usage
fi
if [ -z "$CONFIGURATION" ]; then
    log_error "--configuration is required"
    usage
fi
if [ -z "$SCHEME" ]; then
    log_error "--scheme is required"
    usage
fi
if [ -z "$ARCHITECTURE_TARGET" ]; then
    log_error "--architecture-target is required"
    usage
fi

if [ ! -f "$PACKAGE_PATH/Package.swift" ]; then
    log_error "Package.swift not found at $PACKAGE_PATH"
    exit 1
fi

ARCHIVE_DIR="$OUTPUT_DIR/archive/$SCHEME"
DERIVED_DATA="$OUTPUT_DIR/DerivedData"
LIB_DIR="$OUTPUT_DIR/lib/$SCHEME"
SDK_VERSION="$(read_xcconfig_value_or_exit --key MARKETING_VERSION \
    --file "$PACKAGE_PATH/Sources/Configuration/Versioning.xcconfig")"

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

# Resolve into the archive's package cache before selecting its generated scheme.
# Xcode 26 can lose that scheme when the first checkout regenerates schemes mid-archive.
begin_group "Resolve package schemes"
xcodebuild -list -workspace "$PACKAGE_PATH" \
    -clonedSourcePackagesDirPath "$DERIVED_DATA/SourcePackages" \
    2>&1 | tee "$ARCHIVE_DIR/$SDK-resolve.log"
end_group

# Archive clears its intermediates first, so keep the verifier's module-map link outside them.
module_maps="$OUTPUT_DIR/modulemaps/$SCHEME/$SDK"
mkdir -p "$module_maps" "$DERIVED_DATA"
module_maps="$(cd "$module_maps" && pwd)"
platform_suffix="-$SDK"
if [ "$SDK" = macosx ]; then platform_suffix=""; fi
generated_maps="$(cd "$DERIVED_DATA" && pwd)/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/IntermediateBuildFilesPath/GeneratedModuleMaps$platform_suffix"
ln -sf "$generated_maps/SentryHeaders.modulemap" "$module_maps/module.modulemap"

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
    -clonedSourcePackagesDirPath "$DERIVED_DATA/SourcePackages" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    VERSIONING_SYSTEM=apple-generic \
    CURRENT_PROJECT_VERSION="$SDK_VERSION" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    ENABLE_CODE_COVERAGE=NO \
    "SWIFT_INCLUDE_PATHS=\$(inherited) \"$module_maps\" \"$PACKAGE_PATH/Sources/Sentry/Public\"" \
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

# Dependencies may archive extra legacy architectures that the selected target does not
# support. Distributing their union would advertise incomplete slices (e.g. armv7k).
# Use the target's architecture set, but fail rather than silently omit a required slice.
target_objects=()

for object in "${objects[@]}"; do
    if [ "${object##*/}" = "$ARCHITECTURE_TARGET.o" ]; then
        target_objects+=( "$object" )
    fi
done

if [ "${#target_objects[@]}" -ne 1 ]; then
    log_error "Expected one archived $ARCHITECTURE_TARGET.o, found ${#target_objects[@]}"
    exit 1
fi

read -r -a target_archs <<< "$(xcrun lipo -archs "${target_objects[0]}")"
if [ "${#target_archs[@]}" -eq 0 ]; then
    log_error "Could not read archived $ARCHITECTURE_TARGET architectures"
    exit 1
fi

for object in "${objects[@]}"; do
    for arch in "${target_archs[@]}"; do
        if ! xcrun lipo "$object" -verify_arch "$arch"; then
            log_error "Missing required $ARCHITECTURE_TARGET architecture ($arch) in $object"
            exit 1
        fi
    done
done

log_info "  Distribution architectures: ${target_archs[*]}"

archive_dir="$LIB_DIR/$SDK"
debug_static_lib="$archive_dir/lib${SCHEME}-Debug.a"
static_lib="$archive_dir/lib${SCHEME}.a"
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
    for arch in "${target_archs[@]}"; do
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
# It is an intermediate and is not distributed as the static library.
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

# SwiftPM installs objects, but not its interfaces, generated headers or resource bundles.
# Preserve those beside the objects so framework packaging needs only this archive.
build_products="$DERIVED_DATA/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/BuildProductsPath/$CONFIGURATION$platform_suffix"
mkdir -p "$archive_path/Products/Swift" "$archive_path/Products/Resources"
for module in "$build_products"/*.swiftmodule; do
    [ -d "$module" ] || continue
    cp -RL "$module" "$archive_path/Products/Swift/"
done
for header in "$generated_maps"/*-Swift.h; do
    [ -f "$header" ] || continue
    cp "$header" "$archive_path/Products/Swift/"
done
for bundle in "$build_products"/*.bundle; do
    [ -d "$bundle" ] || continue
    cp -RL "$bundle" "$archive_path/Products/Resources/"
done

log_info "Static slice built: $static_lib"
log_info "Dynamic-linking intermediate built: $debug_static_lib"
