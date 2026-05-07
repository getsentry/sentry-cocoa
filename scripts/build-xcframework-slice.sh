#!/bin/bash
#
# Builds a single slice of the SDK to be packaged into an XCFramework
#
# Parameters:
#   $1 - sdk (e.g., iphoneos, iphonesimulator, macosx)
#   $2 - scheme (e.g., Sentry, SentryObjC)
#   $3 - suffix (optional, e.g., -Dynamic)
#   $4 - MACH_O_TYPE (mh_dylib or staticlib)
#   $5 - configuration_suffix (optional)
set -eoux pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

sdk="${1:-}"
scheme="$2"
suffix="${3:-}"
MACH_O_TYPE="${4-mh_dylib}"
configuration_suffix="${5-}"

resolved_configuration="Release$configuration_suffix"
resolved_product_name="$scheme$configuration_suffix.framework"
OTHER_LDFLAGS=""

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

print_archive_diagnostics() {
    local frameworks_path="${sentry_xcarchive_path}/Products/Library/Frameworks"
    local framework_path="${frameworks_path}/${resolved_product_name}"
    local binary_name="${resolved_product_name%.framework}"
    local binary_path="${framework_path}/${binary_name}"
    local architectures=""
    local modules_path=""

    if [ -f "${framework_path}/Versions/A/${binary_name}" ]; then
        binary_path="${framework_path}/Versions/A/${binary_name}"
    fi

    begin_group "Archive diagnostics for ${slice_id}"
    log_notice "Framework: ${framework_path}"

    if [ -f "$binary_path" ]; then
        log_notice "Binary: ${binary_path}"
        if architectures="$(xcrun lipo -archs "$binary_path" 2>/dev/null)"; then
            log_notice "Architectures: ${architectures}"
        else
            log_warning "Could not read architectures with lipo; falling back to file"
            file "$binary_path" || true
        fi
    else
        log_warning "Missing binary: ${binary_path}"
    fi

    if [ -d "${framework_path}/Versions/A/Modules" ]; then
        modules_path="${framework_path}/Versions/A/Modules"
    elif [ -d "${framework_path}/Modules" ]; then
        modules_path="${framework_path}/Modules"
    fi

    if [ -n "$modules_path" ]; then
        log_notice "Module files in ${modules_path}:"
        find "$modules_path" -maxdepth 2 -type f -print | sort
    else
        log_warning "Missing module directory for ${resolved_product_name}"
    fi

    end_group
}

if [ "$sdk" = "maccatalyst" ]; then
    # we can't use the "archive" action here because it doesn't support the -destination option, which we need to build the maccatalyst slice. so we'll have to build it manually and then copy the build product to an xcarchive directory we create.
    # shellcheck disable=SC2086
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -project Sentry.xcodeproj/ \
        -scheme "$scheme" \
        -configuration "$resolved_configuration" \
        -sdk iphoneos \
        -destination 'platform=macOS,variant=Mac Catalyst' \
        -derivedDataPath ./XCFrameworkBuildPath/DerivedData \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY= \
        MACH_O_TYPE="$MACH_O_TYPE" \
        SUPPORTS_MACCATALYST=YES \
        ENABLE_CODE_COVERAGE=NO \
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS" \
        OTHER_LDFLAGS="$OTHER_LDFLAGS" 2>&1 | tee "${slice_id}.maccatalyst.log" | xcbeautify --preserve-unbeautified

    maccatalyst_build_product_directory="XCFrameworkBuildPath/DerivedData/Build/Products/$resolved_configuration-maccatalyst"

    maccatalyst_xcarchive_framework_directory="${sentry_xcarchive_path}/Products/Library/Frameworks"
    mkdir -p "${maccatalyst_xcarchive_framework_directory}"
    cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}" "${maccatalyst_xcarchive_framework_directory}"

    if [ -d "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" ]; then
        maccatalyst_archive_dsym_destination="${output_xcarchive_path}/maccatalyst.xcarchive/dSYMs"
        mkdir "${maccatalyst_archive_dsym_destination}"
        cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" "${maccatalyst_archive_dsym_destination}"
    fi
else
    # shellcheck disable=SC2086
    set -o pipefail && NSUnbufferedIO=YES xcodebuild archive \
        -project Sentry.xcodeproj/ \
        -scheme "$scheme" \
        -configuration "$resolved_configuration" \
        -sdk "$sdk" \
        -archivePath "./$sentry_xcarchive_path" \
        CODE_SIGNING_REQUIRED=NO \
        SKIP_INSTALL=NO \
        CODE_SIGN_IDENTITY= \
        MACH_O_TYPE="$MACH_O_TYPE" \
        ENABLE_CODE_COVERAGE=NO \
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS" \
        OTHER_LDFLAGS="$OTHER_LDFLAGS" 2>&1 | tee "${slice_id}.log" | xcbeautify --preserve-unbeautified
fi

print_archive_diagnostics

if [ "$MACH_O_TYPE" = "staticlib" ]; then
    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        infoPlistPath="Resources/Info.plist"
    else
        infoPlistPath="Info.plist"
    fi
    # This workaround is necessary to make Sentry Static framework to work
    # More information in here: https://github.com/getsentry/sentry-cocoa/issues/3769
    # The version 100 seems to work with all Xcode up to 15.4
    plutil -replace "MinimumOSVersion" -string "100.0" "$sentry_xcarchive_path/Products/Library/Frameworks/${resolved_product_name}/$infoPlistPath"
fi
