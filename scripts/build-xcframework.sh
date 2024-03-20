#!/bin/bash

set -eou pipefail

sdks=( iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator )

rm -rf Carthage/
mkdir Carthage

ALL_SDKS=$(xcodebuild -showsdks)

generate_xcframework() {
    local scheme="$1"
    local sufix="${2:-}"
    local MACH_O_TYPE="${3-mh_dylib}"
    
    local createxcframework="xcodebuild -create-xcframework "
    
    rm -rf Carthage/DerivedData
    
    for sdk in "${sdks[@]}"; do
        if [[ -n "$(grep "${sdk}" <<< "$ALL_SDKS")" ]]; then
            xcodebuild archive -project Sentry.xcodeproj/ -scheme "$scheme" -configuration Release -sdk "$sdk" -archivePath ./Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive CODE_SIGNING_REQUIRED=NO SKIP_INSTALL=NO CODE_SIGN_IDENTITY= CARTHAGE=YES MACH_O_TYPE=$MACH_O_TYPE ENABLE_CODE_COVERAGE=NO
                 
            createxcframework+="-framework Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework "

            if [ "$MACH_O_TYPE" = "staticlib" ]; then
                local infoPlist="Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework/Info.plist"
                
                if [ ! -e "$infoPlist" ]; then
                    infoPlist="Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework/Resources/Info.plist"
                fi
                # This workaround is necessary to make Sentry Static framework to work
                #More information in here: https://github.com/getsentry/sentry-cocoa/issues/3769
                plutil -replace "MinimumOSVersion" -string "9999" "$infoPlist"
            fi
            
            if [ -d "Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM" ]; then
                # Has debug symbols
                    createxcframework+="-debug-symbols $(pwd -P)/Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM "
            fi
        else
            echo "${sdk} SDK not found"
        fi
    done
    
    #Create framework for mac catalyst
    xcodebuild -project Sentry.xcodeproj/ -scheme "$scheme" -configuration Release -sdk macosx -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath ./Carthage/DerivedData CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= CARTHAGE=YES MACH_O_TYPE=$MACH_O_TYPE SUPPORTS_MACCATALYST=YES ENABLE_CODE_COVERAGE=NO
    
    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        local infoPlist="Carthage/DerivedData/Build/Products/Release-maccatalyst/${scheme}.framework/Resources/Info.plist"
        plutil -replace "MinimumOSVersion" -string "9999" "$infoPlist"
    fi
    
    createxcframework+="-framework Carthage/DerivedData/Build/Products/Release-maccatalyst/${scheme}.framework "
    if [ -d "Carthage/DerivedData/Build/Products/Release-maccatalyst/${scheme}.framework.dSYM" ]; then
        createxcframework+="-debug-symbols $(pwd -P)/Carthage/DerivedData/Build/Products/Release-maccatalyst/${scheme}.framework.dSYM "
    fi
    
    createxcframework+="-output Carthage/${scheme}${sufix}.xcframework"
    $createxcframework
}

generate_xcframework "Sentry" "-Dynamic"

generate_xcframework "Sentry" "" staticlib

generate_xcframework "SentrySwiftUI"
