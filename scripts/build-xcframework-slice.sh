#!/bin/bash
#
# Builds a single slice of the SDK to be packaged into an XCFramework

set -eou pipefail

sdk="${1:-}"

ALL_SDKS=$(xcodebuild -showsdks)

if ! [[ $ALL_SDKS =~ $sdk ]]; then
    echo "${sdk} SDK not found"
    exit 1
fi

scheme="$2"
suffix="${3:-}"
MACH_O_TYPE="${4-mh_dylib}"
configuration_suffix="${5-}"
no_maccatalyst="${6:-false}"

GCC_GENERATE_DEBUGGING_SYMBOLS="YES"

resolved_configuration="Release$configuration_suffix"
resolved_product_name="$scheme$configuration_suffix"
OTHER_LDFLAGS=""

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

set -o pipefail && NSUnbufferedIO=YES xcodebuild archive \
    -project Sentry.xcodeproj/ \
    -scheme "$scheme" \
    -configuration "$resolved_configuration" \
    -sdk "$sdk" \
    -archivePath "./Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive" \
    CODE_SIGNING_REQUIRED=NO \
    SKIP_INSTALL=NO \
    CODE_SIGN_IDENTITY= \
    CARTHAGE=YES \
    MACH_O_TYPE="$MACH_O_TYPE" \
    ENABLE_CODE_COVERAGE=NO \
    GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS" \
    OTHER_LDFLAGS="$OTHER_LDFLAGS" > "${slice_id}.log" 2>&1

xcframework_command_args+="-framework Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/Products/Library/Frameworks/${resolved_product_name}.framework "

if [ "$MACH_O_TYPE" = "staticlib" ]; then
    infoPlist="Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/Products/Library/Frameworks/${resolved_product_name}.framework/Info.plist"

    if [ ! -e "$infoPlist" ]; then
        infoPlist="Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/Products/Library/Frameworks/${resolved_product_name}.framework/Resources/Info.plist"
    fi
    # This workaround is necessary to make Sentry Static framework to work
    # More information in here: https://github.com/getsentry/sentry-cocoa/issues/3769
    # The version 100 seems to work with all Xcode up to 15.4
    plutil -replace "MinimumOSVersion" -string "100.0" "$infoPlist"
fi

if [ -d "Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/dSYMs/${resolved_product_name}.framework.dSYM" ]; then
    # Has debug symbols
    xcframework_command_args+="-debug-symbols $(pwd -P)/Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/dSYMs/${resolved_product_name}.framework.dSYM "
fi

if [ "$no_maccatalyst" = "false" ]; then
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
        OTHER_LDFLAGS="$OTHER_LDFLAGS" > "${slice_id}.maccatalyst.log" 2>&1

    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        infoPlist="Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${scheme}.framework/Resources/Info.plist"
        plutil -replace "MinimumOSVersion" -string "100.0" "$infoPlist"
    fi

    createxcframework+="-framework Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${resolved_product_name}.framework "
    if [ -d "Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${resolved_product_name}.framework.dSYM" ]; then
        createxcframework+="-debug-symbols $(pwd -P)/Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${resolved_product_name}.framework.dSYM "
    fi
fi

if [ "${CI:-}" = "true" ]; then
    echo "xcframework_command_args_${sdk}_${suffix}_${MACH_O_TYPE}_${configuration_suffix}=$xcframework_command_args" >> "$GITHUB_ENV"
fi
