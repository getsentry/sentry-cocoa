#!/bin/bash
#
# Builds a single slice of the SDK to be packaged into an XCFramework

set -eoux pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <sdk> <scheme> [suffix] [mach_o_type] [configuration_suffix]

Build a single SDK slice to be packaged into an XCFramework.

ARGUMENTS:
    sdk                     Target SDK (e.g., iphoneos, macosx, maccatalyst, watchos)
    scheme                  Xcode scheme name (e.g., Sentry, SentrySwiftUI)
    suffix                  Output name suffix, e.g. '-Dynamic' (default: empty)
    mach_o_type             Mach-O type: mh_dylib or staticlib (default: mh_dylib)
    configuration_suffix    Build configuration suffix (default: empty)

EXAMPLES:
    $(basename "$0") iphoneos Sentry "-Dynamic" mh_dylib
    $(basename "$0") macosx Sentry "" staticlib

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ $# -lt 2 ]]; then
    log_error "Expected at least 2 arguments (sdk, scheme), got $#"
    usage
fi

sdk="${1:-}"
scheme="$2"
suffix="${3:-}"
MACH_O_TYPE="${4-mh_dylib}"
configuration_suffix="${5-}"

log_info "Building XCFramework slice:"
log_info "  SDK:                  $sdk"
log_info "  Scheme:               $scheme"
log_info "  Suffix:               ${suffix:-(none)}"
log_info "  Mach-O type:          $MACH_O_TYPE"
log_info "  Configuration suffix: ${configuration_suffix:-(none)}"

resolved_configuration="Release$configuration_suffix"
resolved_product_name="$scheme$configuration_suffix.framework"
OTHER_LDFLAGS=""

log_info "  Configuration:        $resolved_configuration"
log_info "  Product name:         $resolved_product_name"

GCC_GENERATE_DEBUGGING_SYMBOLS="YES"
if [ "$MACH_O_TYPE" = "staticlib" ]; then
    #For static framework we disabled symbols because they are not distributed in the framework causing warnings.
    GCC_GENERATE_DEBUGGING_SYMBOLS="NO"
fi

rm -rf XCFrameworkBuildPath/DerivedData

## watchos and watchsimulator don't support make_mergeable: ld: unknown option: -make_mergeable
## For other dynamic frameworks, add -make_mergeable (append to existing flags)
if [[ "$sdk" != "watchos" && "$sdk" != "watchsimulator" ]] && [ "$MACH_O_TYPE" != "staticlib" ]; then
    OTHER_LDFLAGS="$OTHER_LDFLAGS -Wl,-make_mergeable"
fi

slice_id="${scheme}${suffix}-${sdk}"

output_xcarchive_path="XCFrameworkBuildPath/archive/${scheme}${suffix}"
sentry_xcarchive_path="$output_xcarchive_path/${sdk}.xcarchive"

if [ "$sdk" = "maccatalyst" ]; then
    # we can't use the "archive" action here because it doesn't support the -destination option, which we need to build the maccatalyst slice. so we'll have to build it manually and then copy the build product to an xcarchive directory we create.
    begin_group "Build ${slice_id} (maccatalyst)"
    maccatalyst_args=(
        -project Sentry.xcodeproj/
        -scheme "$scheme"
        -configuration "$resolved_configuration"
        -sdk iphoneos
        -destination "generic/platform=macOS,variant=Mac Catalyst"
        -derivedDataPath ./XCFrameworkBuildPath/DerivedData
        CODE_SIGNING_REQUIRED=NO
        SKIP_INSTALL=NO
        CODE_SIGN_IDENTITY=
        MACH_O_TYPE="$MACH_O_TYPE"
        SUPPORTS_MACCATALYST=YES
        ENABLE_CODE_COVERAGE=NO
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS"
        OTHER_LDFLAGS="$OTHER_LDFLAGS"
    )
    set -o pipefail && NSUnbufferedIO=YES xcodebuild "${maccatalyst_args[@]}" 2>&1 | tee "${slice_id}.maccatalyst.log" | xcbeautify --preserve-unbeautified
    end_group

    maccatalyst_build_product_directory="XCFrameworkBuildPath/DerivedData/Build/Products/$resolved_configuration-maccatalyst"

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
        -project Sentry.xcodeproj/
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
        MACH_O_TYPE="$MACH_O_TYPE"
        ENABLE_CODE_COVERAGE=NO
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS"
        OTHER_LDFLAGS="$OTHER_LDFLAGS"
    )

    archive_args=(
        archive
        "${xcodebuild_args[@]}"
        -archivePath "./$sentry_xcarchive_path"
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
