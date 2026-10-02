#!/bin/bash
#
# Builds a single slice of the SDK to be packaged into an XCFramework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

sdk=""
scheme=""
suffix=""
MACH_O_TYPE="mh_dylib"
configuration_suffix=""
product_name=""
project="Sentry.xcodeproj/"
build_path="XCFrameworkBuildPath"
extra_build_settings=()

usage() {
    log_info "Usage: $0 --sdk <sdk> --scheme <name> [options]"
    log_info "  -d, --sdk <sdk>                    Target SDK (required)"
    log_info "  -s, --scheme <name>                Xcode scheme (required)"
    log_info "  -u, --suffix <suffix>              Archive name suffix (default: empty)"
    log_info "  -m, --mach-o-type <type>           mh_dylib, staticlib or inherit (default: mh_dylib)"
    log_info "  -c, --configuration-suffix <s>    Release configuration suffix (default: empty)"
    log_info "  -p, --product-name <name>          Framework name (default: scheme+configuration suffix)"
    log_info "  -j, --project <path>               Xcode project (default: Sentry.xcodeproj)"
    log_info "  -b, --build-path <path>            Build directory (default: XCFrameworkBuildPath)"
    log_info "  -x, --build-setting <KEY=VALUE>   Extra xcodebuild setting (repeatable)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ $# -lt 2 && "$1" != -h && "$1" != --help ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case "$1" in
        -d|--sdk)                  sdk="$2"; shift 2 ;;
        -s|--scheme)               scheme="$2"; shift 2 ;;
        -u|--suffix)               suffix="$2"; shift 2 ;;
        -m|--mach-o-type)          MACH_O_TYPE="$2"; shift 2 ;;
        -c|--configuration-suffix) configuration_suffix="$2"; shift 2 ;;
        -p|--product-name)         product_name="$2"; shift 2 ;;
        -j|--project)              project="$2"; shift 2 ;;
        -b|--build-path)           build_path="$2"; shift 2 ;;
        -x|--build-setting)        extra_build_settings+=("$2"); shift 2 ;;
        -h|--help)                 usage ;;
        *)                         log_error "Unknown argument: $1"; usage ;;
    esac
done

if [[ -z "$sdk" || -z "$scheme" ]]; then
    log_error "--sdk and --scheme are required"
    usage
fi
if [[ -z "$build_path" || "$build_path" == / ]]; then
    log_error "--build-path must be a non-root directory"
    exit 1
fi
product_name="${product_name:-$scheme$configuration_suffix}"

log_info "Building XCFramework slice:"
log_info "  SDK:                  $sdk"
log_info "  Scheme:               $scheme"
log_info "  Suffix:               ${suffix:-(none)}"
log_info "  Mach-O type:          $MACH_O_TYPE"
log_info "  Configuration suffix: ${configuration_suffix:-(none)}"
log_info "  Product name:         $product_name"
if [[ ${#extra_build_settings[@]} -gt 0 ]]; then
    log_info "  Extra build settings: ${extra_build_settings[*]}"
fi

resolved_configuration="Release$configuration_suffix"
resolved_product_name="$product_name.framework"
OTHER_LDFLAGS=""

log_info "  Configuration:        $resolved_configuration"
log_info "  Resolved product:     $resolved_product_name"

GCC_GENERATE_DEBUGGING_SYMBOLS="YES"
if [ "$MACH_O_TYPE" = "staticlib" ]; then
    #For static framework we disabled symbols because they are not distributed in the framework causing warnings.
    GCC_GENERATE_DEBUGGING_SYMBOLS="NO"
fi

# When MACH_O_TYPE is 'inherit', the target's xcconfig controls the product type
# and we must NOT pass MACH_O_TYPE on the command line, as that would propagate
# to every sub-target in the build (including SPM package targets) and break their link.
mach_o_type_override=()
if [ "$MACH_O_TYPE" != "inherit" ]; then
    mach_o_type_override=( MACH_O_TYPE="$MACH_O_TYPE" )
fi

# Each slice uses the same derived-data directory, so clear it before building.
rm -rf "$build_path/DerivedData"

## watchos and watchsimulator don't support make_mergeable: ld: unknown option: -make_mergeable
## For other dynamic frameworks, add -make_mergeable (append to existing flags)
if [[ "$sdk" != "watchos" && "$sdk" != "watchsimulator" ]] && [ "$MACH_O_TYPE" != "staticlib" ]; then
    OTHER_LDFLAGS="$OTHER_LDFLAGS -Wl,-make_mergeable"
fi

slice_id="${scheme}${suffix}-${sdk}"

output_xcarchive_path="$build_path/archive/${scheme}${suffix}"
sentry_xcarchive_path="$output_xcarchive_path/${sdk}.xcarchive"

if [ "$sdk" = "maccatalyst" ]; then
    # we can't use the "archive" action here because it doesn't support the -destination option, which we need to build the maccatalyst slice. so we'll have to build it manually and then copy the build product to an xcarchive directory we create.
    begin_group "Build ${slice_id} (maccatalyst)"
    maccatalyst_args=(
        -project "$project"
        -scheme "$scheme"
        -configuration "$resolved_configuration"
        -sdk iphoneos
        -destination "generic/platform=macOS,variant=Mac Catalyst"
        -derivedDataPath "$build_path/DerivedData"
        CODE_SIGNING_REQUIRED=NO
        SKIP_INSTALL=NO
        CODE_SIGN_IDENTITY=
        "${mach_o_type_override[@]+${mach_o_type_override[@]}}"
        SUPPORTS_MACCATALYST=YES
        ENABLE_CODE_COVERAGE=NO
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS"
        OTHER_LDFLAGS="$OTHER_LDFLAGS"
        "${extra_build_settings[@]+${extra_build_settings[@]}}"
    )
    set -o pipefail && NSUnbufferedIO=YES xcodebuild "${maccatalyst_args[@]}" 2>&1 | tee "${slice_id}.maccatalyst.log" | xcbeautify --preserve-unbeautified
    end_group

    maccatalyst_build_product_directory="$build_path/DerivedData/Build/Products/$resolved_configuration-maccatalyst"

    begin_group "Assemble maccatalyst xcarchive (${slice_id})"
    maccatalyst_xcarchive_framework_directory="${sentry_xcarchive_path}/Products/Library/Frameworks"
    mkdir -p "${maccatalyst_xcarchive_framework_directory}"
    log_info "Copying framework to ${maccatalyst_xcarchive_framework_directory}"
    cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}" "${maccatalyst_xcarchive_framework_directory}"

    if [ -d "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" ]; then
        maccatalyst_archive_dsym_destination="${output_xcarchive_path}/maccatalyst.xcarchive/dSYMs"
        mkdir "${maccatalyst_archive_dsym_destination}"
        log_info "Copying dSYM to ${maccatalyst_archive_dsym_destination}"
        cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" "${maccatalyst_archive_dsym_destination}"
    else
        log_info "No dSYM found for maccatalyst slice (GCC_GENERATE_DEBUGGING_SYMBOLS=$GCC_GENERATE_DEBUGGING_SYMBOLS)"
    fi
    end_group
else
    begin_group "Archive ${slice_id}"
    xcodebuild_args=(
        -project "$project"
        -scheme "$scheme"
        -configuration "$resolved_configuration"
        -sdk "$sdk"
    )

    if [ "$sdk" = "macosx" ]; then
        xcodebuild_args+=(-destination "generic/platform=macOS")
    fi

    build_setting_overrides=(
        CODE_SIGNING_REQUIRED=NO
        SKIP_INSTALL=NO
        CODE_SIGN_IDENTITY=
        "${mach_o_type_override[@]+${mach_o_type_override[@]}}"
        ENABLE_CODE_COVERAGE=NO
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS"
        OTHER_LDFLAGS="$OTHER_LDFLAGS"
        "${extra_build_settings[@]+${extra_build_settings[@]}}"
    )

    archive_args=(
        archive
        "${xcodebuild_args[@]}"
        -archivePath "$sentry_xcarchive_path"
        "${build_setting_overrides[@]}"
    )

    set -o pipefail && NSUnbufferedIO=YES xcodebuild "${archive_args[@]}" 2>&1 | tee "${slice_id}.log" | xcbeautify --preserve-unbeautified
    end_group
fi

if [ "$MACH_O_TYPE" = "staticlib" ]; then
    begin_group "Patch Info.plist for static framework (${slice_id})"
    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        infoPlistPath="Resources/Info.plist"
    else
        infoPlistPath="Info.plist"
    fi
    # This workaround is necessary to make Sentry Static framework to work
    # More information in here: https://github.com/getsentry/sentry-cocoa/issues/3769
    # The version 100 seems to work with all Xcode up to 15.4
    log_info "Patching MinimumOSVersion to 100.0 in $infoPlistPath"
    plutil -replace "MinimumOSVersion" -string "100.0" "$sentry_xcarchive_path/Products/Library/Frameworks/${resolved_product_name}/$infoPlistPath"
    end_group
fi

log_info "Slice ${slice_id} built successfully"
