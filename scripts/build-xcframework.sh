#!/bin/bash

sdks=(iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator)

rm -rf Carthage/
mkdir Carthage

ALL_SDKS=$(xcodebuild -showsdks)

generate_xcframework() {
    local scheme="$1"
    local sufix="${2:-}"
    local MACH_O_TYPE="${3-mh_dylib}"
    
    for sdk in "${sdks[@]}"; do
        if [[ -n "$(grep "${sdk}" <<< "$ALL_SDKS")" ]]; then
            xcodebuild archive -project Sentry.xcodeproj/ -scheme "$scheme" -configuration Release -sdk "$sdk" -archivePath ./Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive CODE_SIGNING_REQUIRED=NO SKIP_INSTALL=NO CODE_SIGN_IDENTITY= CARTHAGE=YES MACH_O_TYPE=$MACH_O_TYPE
            
            if [ -d "Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM" ]; then
                # Has debug symbols
                xcodebuild -create-xcframework -framework Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework -debug-symbols "$(pwd -P)"/Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM -output Carthage/${scheme}${sufix}.xcframework
            else
                # Has no debug symbols - static libs or projects configured to not produce it
                xcodebuild -create-xcframework -framework Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework -output Carthage/${scheme}${sufix}.xcframework
            fi
        else
            echo "${sdk} SDK not found"
        fi
    done
}

# Create Sentry.xcframework
generate_xcframework "Sentry" "-Dynamic"

generate_xcframework "Sentry" "" staticlib

# Create SentrySwiftUI.xcframework
generate_xcframework "SentrySwiftUI"
