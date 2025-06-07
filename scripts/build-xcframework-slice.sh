#!/bin/bash
#
# Builds a single slice of the SDK to be packaged into an XCFramework

set -eoux pipefail

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

rm -rf Carthage/DerivedData

## watchos and watchsimulator don't support make_mergeable: ld: unknown option: -make_mergeable
if [[ "$sdk" == "watchos" || "$sdk" == "watchsimulator" ]]; then
    OTHER_LDFLAGS=""
elif [ "$MACH_O_TYPE" != "staticlib" ]; then
    OTHER_LDFLAGS="-Wl,-make_mergeable"
fi

slice_id="${scheme}${suffix}-${sdk}"

carthage_xcarchive_path="Carthage/archive/${scheme}${suffix}"

if [ "$sdk" = "maccatalyst" ]; then
    #Create framework for mac catalyst
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -project Sentry.xcodeproj/ \
        -scheme "$scheme" \
        -configuration "$resolved_configuration" \
        -sdk iphoneos \
        -destination 'platform=macOS,variant=Mac Catalyst' \
        -derivedDataPath ./Carthage/DerivedData \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY= \
        CARTHAGE=YES \
        MACH_O_TYPE="$MACH_O_TYPE" \
        SUPPORTS_MACCATALYST=YES \
        ENABLE_CODE_COVERAGE=NO \
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS" \
        OTHER_LDFLAGS="$OTHER_LDFLAGS" 2>&1 | tee "${slice_id}.maccatalyst.log" | xcbeautify

    maccatalyst_build_product_directory="Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst"

    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        infoPlist="${maccatalyst_build_product_directory}/${resolved_product_name}/Resources/Info.plist"
        plutil -replace "MinimumOSVersion" -string "100.0" "$infoPlist"
    fi

    maccatalyst_archive_directory="${carthage_xcarchive_path}/maccatalyst.xcarchive/Products/Library/Frameworks"
    mkdir -p "${maccatalyst_archive_directory}"
    cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}" "${maccatalyst_archive_directory}"

    if [ -d "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" ]; then
        maccatalyst_archive_dsym_destination="${carthage_xcarchive_path}/maccatalyst.xcarchive/dSYMs"
        mkdir "${maccatalyst_archive_dsym_destination}"
        cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" "${maccatalyst_archive_dsym_destination}"
    fi
else
    sentry_xcarchive_path="$carthage_xcarchive_path/${sdk}.xcarchive"

    set -o pipefail && NSUnbufferedIO=YES xcodebuild archive \
        -project Sentry.xcodeproj/ \
        -scheme "$scheme" \
        -configuration "$resolved_configuration" \
        -sdk "$sdk" \
        -archivePath "./$sentry_xcarchive_path" \
        CODE_SIGNING_REQUIRED=NO \
        SKIP_INSTALL=NO \
        CODE_SIGN_IDENTITY= \
        CARTHAGE=YES \
        MACH_O_TYPE="$MACH_O_TYPE" \
        ENABLE_CODE_COVERAGE=NO \
        GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS" \
        OTHER_LDFLAGS="$OTHER_LDFLAGS" 2>&1 | tee "${slice_id}.log" | xcbeautify

    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        if [ "$sdk" = "macosx" ]; then
            infoPlistPath="Resources/Info.plist"
        else
            infoPlistPath="Info.plist"
        fi
        # This workaround is necessary to make Sentry Static framework to work
        # More information in here: https://github.com/getsentry/sentry-cocoa/issues/3769
        # The version 100 seems to work with all Xcode up to 15.4
        plutil -replace "MinimumOSVersion" -string "100.0" "$sentry_xcarchive_path/Products/Library/Frameworks/${resolved_product_name}/$infoPlistPath"
    fi
fi
