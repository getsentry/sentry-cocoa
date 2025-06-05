#!/bin/bash

set -eou pipefail

args="${1:-}"

if [ "$args" = "iOSOnly" ]; then
    sdks=( iphoneos iphonesimulator )
elif [ "$args" = "gameOnly" ]; then
    sdks=( iphoneos iphonesimulator macosx )
else
    sdks=( iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

rm -rf Carthage/
mkdir Carthage

ALL_SDKS=$(xcodebuild -showsdks)

# Build slices for each SDK
for sdk in "${sdks[@]}"; do
    if grep -q "${sdk}" <<< "$ALL_SDKS"; then
        ./scripts/build-xcframework-slice.sh "$sdk" "Sentry" "-Dynamic"
    else
        echo "${sdk} SDK not found"
    fi
done

if [ "$args" != "iOSOnly" ]; then
    for sdk in "${sdks[@]}"; do
        ./scripts/build-xcframework-slice.sh "$sdk" "Sentry" "" "staticlib"
        
        if [ "$args" != "gameOnly" ]; then
            ./scripts/build-xcframework-slice.sh "$sdk" "SentrySwiftUI"
            ./scripts/build-xcframework-slice.sh "$sdk" "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit"
        fi
    done
fi

# Assemble the XCFramework
./scripts/assemble-xcframework.sh "./Carthage/archive" "Sentry"
