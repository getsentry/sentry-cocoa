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

print_command() {
    printf "%q " "$@"
    printf "\n"
}

filter_relevant_build_settings() {
    awk '
        /^Build settings for action/ {
            print
            next
        }
        /^[[:space:]]*(ACTION|ARCHS|BUILD_LIBRARY_FOR_DISTRIBUTION|BUILT_PRODUCTS_DIR|CODE_SIGN_IDENTITY|CODE_SIGNING_ALLOWED|CODE_SIGNING_REQUIRED|CONFIGURATION|CONFIGURATION_BUILD_DIR|CONFIGURATION_TEMP_DIR|CURRENT_ARCH|DWARF_DSYM_FOLDER_PATH|EFFECTIVE_PLATFORM_NAME|ENABLE_CODE_COVERAGE|EXCLUDED_ARCHS|EXECUTABLE_NAME|GCC_GENERATE_DEBUGGING_SYMBOLS|INSTALL_PATH|MACH_O_TYPE|NATIVE_ARCH|ONLY_ACTIVE_ARCH|OTHER_LDFLAGS|PLATFORM_NAME|PRODUCT_NAME|SDK_NAME|SDKROOT|SKIP_INSTALL|SUPPORTED_PLATFORMS|SUPPORTS_MACCATALYST|TARGET_BUILD_DIR|VALID_ARCHS|WRAPPER_NAME)[[:space:]]*=/ {
            print
        }
    '
}

print_xcodebuild_diagnostics() {
    begin_group "Xcode diagnostics for ${slice_id}"

    log_notice "Relevant build settings:"
    print_command xcodebuild -showBuildSettings "$@"
    if ! NSUnbufferedIO=YES xcodebuild -showBuildSettings "$@" 2>&1 | filter_relevant_build_settings; then
        log_warning "Could not read build settings for ${slice_id}"
    fi

    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        log_notice "Available destinations:"
        print_command xcodebuild -showdestinations "$@"
        if ! NSUnbufferedIO=YES xcodebuild -showdestinations "$@" 2>&1 | sed "s/^/    /"; then
            log_warning "Could not read destinations for ${slice_id}"
        fi
    fi

    end_group
}

print_plist_value() {
    local plist_path="$1"
    local key="$2"
    local value=""

    if value="$(/usr/libexec/PlistBuddy -c "Print :${key}" "$plist_path" 2>/dev/null)"; then
        if [[ "$value" == *$'\n'* ]]; then
            log_notice "${key}:"
            printf "%s\n" "$value" | sed "s/^/    /"
        else
            log_notice "${key}: ${value}"
        fi
    fi
}

print_plist_diagnostics() {
    local title="$1"
    local plist_path="$2"

    if [ ! -f "$plist_path" ]; then
        log_warning "Missing ${title}: ${plist_path}"
        return
    fi

    log_notice "${title}: ${plist_path}"
    print_plist_value "$plist_path" "ApplicationProperties:CFBundleIdentifier"
    print_plist_value "$plist_path" "ApplicationProperties:CFBundleShortVersionString"
    print_plist_value "$plist_path" "ApplicationProperties:SigningIdentity"
    print_plist_value "$plist_path" "ArchiveVersion"
    print_plist_value "$plist_path" "CFBundleExecutable"
    print_plist_value "$plist_path" "CFBundleIdentifier"
    print_plist_value "$plist_path" "CFBundlePackageType"
    print_plist_value "$plist_path" "CFBundleShortVersionString"
    print_plist_value "$plist_path" "CFBundleSupportedPlatforms"
    print_plist_value "$plist_path" "DTPlatformName"
    print_plist_value "$plist_path" "DTSDKName"
    print_plist_value "$plist_path" "LSMinimumSystemVersion"
    print_plist_value "$plist_path" "MinimumOSVersion"
    print_plist_value "$plist_path" "Name"
    print_plist_value "$plist_path" "SchemeName"
}

print_archive_diagnostics() {
    local frameworks_path="${sentry_xcarchive_path}/Products/Library/Frameworks"
    local framework_path="${frameworks_path}/${resolved_product_name}"
    local binary_name="${resolved_product_name%.framework}"
    local binary_path="${framework_path}/${binary_name}"
    local architectures=""
    local file_info=""
    local framework_info_plist_path="${framework_path}/Info.plist"
    local modules_path=""

    if [ -f "${framework_path}/Versions/A/${binary_name}" ]; then
        binary_path="${framework_path}/Versions/A/${binary_name}"
        framework_info_plist_path="${framework_path}/Versions/A/Resources/Info.plist"
    fi

    begin_group "Archive diagnostics for ${slice_id}"
    log_notice "Framework: ${framework_path}"
    print_plist_diagnostics "Archive Info.plist" "${sentry_xcarchive_path}/Info.plist"
    print_plist_diagnostics "Framework Info.plist" "$framework_info_plist_path"

    if [ -f "$binary_path" ]; then
        log_notice "Binary: ${binary_path}"
        if architectures="$(xcrun lipo -archs "$binary_path" 2>/dev/null)"; then
            log_notice "Architectures: ${architectures}"
        else
            log_warning "Could not read architectures with lipo; falling back to file"
            file "$binary_path" || true
        fi
        if file_info="$(file "$binary_path")"; then
            printf "%s\n" "$file_info"
        fi
        xcrun lipo -info "$binary_path" || true
        xcrun dwarfdump --uuid "$binary_path" || true
        if [[ "$file_info" == *"ar archive"* ]]; then
            log_notice "Skipping vtool build metadata for static archive"
        else
            xcrun vtool -show-build "$binary_path" || true
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
    maccatalyst_args=(
        -project Sentry.xcodeproj/
        -scheme "$scheme"
        -configuration "$resolved_configuration"
        -sdk iphoneos
        -destination "platform=macOS,variant=Mac Catalyst"
        -derivedDataPath ./XCFrameworkBuildPath/DerivedData
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGN_IDENTITY=
        MACH_O_TYPE="$MACH_O_TYPE"
        SUPPORTS_MACCATALYST=YES
        ENABLE_CODE_COVERAGE=NO
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS"
        OTHER_LDFLAGS="$OTHER_LDFLAGS"
    )

    print_xcodebuild_diagnostics "${maccatalyst_args[@]}"

    set -o pipefail && NSUnbufferedIO=YES xcodebuild "${maccatalyst_args[@]}" 2>&1 | tee "${slice_id}.maccatalyst.log" | xcbeautify --preserve-unbeautified

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

    build_settings_args=(
        "${xcodebuild_args[@]}"
        "${build_setting_overrides[@]}"
    )

    archive_args=(
        archive
        "${xcodebuild_args[@]}"
        -archivePath "./$sentry_xcarchive_path"
        "${build_setting_overrides[@]}"
    )

    print_xcodebuild_diagnostics "${build_settings_args[@]}"

    set -o pipefail && NSUnbufferedIO=YES xcodebuild "${archive_args[@]}" 2>&1 | tee "${slice_id}.log" | xcbeautify --preserve-unbeautified
fi

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

print_archive_diagnostics
