#!/bin/bash
#
# Builds the entire XCFramework with all slices needed for a given deliverable type (iOSOnly, gameOnly or the default full version).
#
# This script originally built all slices and packaged them, but the function to build a slice was split into a separate script so it could be parallelized. The pieces of this script that orchestrated which slices to build then package them up are what remain, so it can be tested on a developer's machine locally to replicate what happens in CI.

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

generate_xcframework() {
    local scheme="$1"
    local suffix="${2:-}"
    local MACH_O_TYPE="${3-mh_dylib}"
    local configuration_suffix="${4-}"
    local createxcframework="xcodebuild -create-xcframework "

    for sdk in "${sdks[@]}"; do
        slice_output=$(./scripts/build-xcframework-slice.sh "$sdk" "$scheme" "$suffix" "$MACH_O_TYPE" "$configuration_suffix")
        createxcframework+=" $slice_output "
    done

    createxcframework+="-output Carthage/${scheme}${suffix}.xcframework"
    $createxcframework
}

generate_xcframework "Sentry" "-Dynamic"

if [ "$args" != "iOSOnly" ]; then
    generate_xcframework "Sentry" "" staticlib
    
    if [ "$args" != "gameOnly" ]; then
        generate_xcframework "SentrySwiftUI"
        generate_xcframework "Sentry" "-WithoutUIKitOrAppKit" mh_dylib WithoutUIKit
    fi
fi
