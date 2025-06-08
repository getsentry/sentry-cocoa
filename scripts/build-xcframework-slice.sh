#!/bin/bash
#
# Builds a single slice of the SDK to be packaged into an XCFramework

set -eou pipefail

sdk="${1:-}"
scheme="$2"
suffix="${3:-}"
MACH_O_TYPE="${4-mh_dylib}"
configuration_suffix="${5-}"

echo "--------------------------------"
echo "Building ${scheme}${suffix} XCFramework slice for ${sdk}"
echo "--------------------------------"

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
sentry_xcarchive_path="$carthage_xcarchive_path/${sdk}.xcarchive"

if [ "$sdk" = "maccatalyst" ]; then
    # we can't use the "archive" action here because it doesn't support the -destination option, which we need to build the maccatalyst slice. so we'll have to build it manually and then copy the build product to an xcarchive directory we create.
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
        OTHER_LDFLAGS="$OTHER_LDFLAGS" 2>&1 | tee "${slice_id}.log" | xcbeautify -qq

    maccatalyst_build_product_directory="Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst"

    maccatalyst_xcarchive_framework_directory="${sentry_xcarchive_path}/Products/Library/Frameworks"
    mkdir -p "${maccatalyst_xcarchive_framework_directory}"
    cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}" "${maccatalyst_xcarchive_framework_directory}"

    if [ -d "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" ]; then
        maccatalyst_archive_dsym_destination="${xcarchive_path}/dSYMs"
        mkdir "${maccatalyst_archive_dsym_destination}"
        cp -R "${maccatalyst_build_product_directory}/${resolved_product_name}.dSYM" "${maccatalyst_archive_dsym_destination}"
    fi
else
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
        OTHER_LDFLAGS="$OTHER_LDFLAGS" 2>&1 | tee "${slice_id}.log" | xcbeautify -qq
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
