#!/bin/bash

set -eou pipefail

if [ "$1" = "reduced" ]; then
    sdks=( iphoneos iphonesimulator )
else
    sdks=( iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

rm -rf Carthage/
mkdir Carthage

ALL_SDKS=$(xcodebuild -showsdks)

generate_xcframework() {
    local scheme="$1"
    local suffix="${2:-}"
    local MACH_O_TYPE="${3-mh_dylib}"
    local configuration_suffix="${4-}"
    local createxcframework="xcodebuild -create-xcframework "
    local GCC_GENERATE_DEBUGGING_SYMBOLS="YES"
    
    local resolved_configuration="Release$configuration_suffix"
    local resolved_product_name="$scheme$configuration_suffix"
    local OTHER_LDFLAGS=""

    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        #For static framework we disabled symbols because they are not distributed in the framework causing warnings.
        GCC_GENERATE_DEBUGGING_SYMBOLS="NO"
    fi
    
    rm -rf Carthage/DerivedData
    
    for sdk in "${sdks[@]}"; do
        if grep -q "${sdk}" <<< "$ALL_SDKS"; then

            ## watchos, watchsimulator dont support make_mergeable: ld: unknown option: -make_mergeable
            if [[ "$sdk" == "watchos" || "$sdk" == "watchsimulator" ]]; then
                OTHER_LDFLAGS=""
            elif [ "$MACH_O_TYPE" != "staticlib" ]; then
                OTHER_LDFLAGS="-Wl,-make_mergeable"
            fi

            xcodebuild archive \
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
                OTHER_LDFLAGS="$OTHER_LDFLAGS"
                 
            createxcframework+="-framework Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/Products/Library/Frameworks/${resolved_product_name}.framework "

            if [ "$MACH_O_TYPE" = "staticlib" ]; then
                local infoPlist="Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/Products/Library/Frameworks/${resolved_product_name}.framework/Info.plist"
                
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
                    createxcframework+="-debug-symbols $(pwd -P)/Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/dSYMs/${resolved_product_name}.framework.dSYM "
            fi
        else
            echo "${sdk} SDK not found"
        fi
    done
    
    # for the case that watch* sdks are last in list
    if [ "$MACH_O_TYPE" != "staticlib" ]; then
        OTHER_LDFLAGS="-Wl,-make_mergeable"
    fi

    if [ "$1" != "reduced" ]; then
        #Create framework for mac catalyst
        xcodebuild \
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
            OTHER_LDFLAGS="$OTHER_LDFLAGS"

        if [ "$MACH_O_TYPE" = "staticlib" ]; then
            local infoPlist="Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${scheme}.framework/Resources/Info.plist"
            plutil -replace "MinimumOSVersion" -string "100.0" "$infoPlist"
        fi
        
        createxcframework+="-framework Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${resolved_product_name}.framework "
        if [ -d "Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${resolved_product_name}.framework.dSYM" ]; then
            createxcframework+="-debug-symbols $(pwd -P)/Carthage/DerivedData/Build/Products/$resolved_configuration-maccatalyst/${resolved_product_name}.framework.dSYM "
        fi
    fi
    
    createxcframework+="-output Carthage/${scheme}${suffix}.xcframework"
    $createxcframework
}

generate_xcframework "Sentry" "-Dynamic"

if [ "$1" != "reduced" ]; then
    generate_xcframework "Sentry" "" staticlib

    generate_xcframework "SentrySwiftUI"

    generate_xcframework "Sentry" "-WithoutUIKitOrAppKit" mh_dylib WithoutUIKit
fi
