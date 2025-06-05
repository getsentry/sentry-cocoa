#!/bin/bash

set -eoux pipefail

# Parse arguments
scheme="$1"
suffix="${2:-}"
MACH_O_TYPE="${3-mh_dylib}"
configuration_suffix="${4-}"
args="${5:-}"

# Define SDKs
if [ "$args" = "iOSOnly" ]; then
    sdks=( iphoneos iphonesimulator )
elif [ "$args" = "gameOnly" ]; then
    sdks=( iphoneos iphonesimulator macosx )
else
    sdks=( iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

# Build slices for each SDK
 for sdk in "${sdks[@]}"; do
     ./scripts/build-xcframework-slice.sh "$sdk" "$scheme" "$suffix" "$MACH_O_TYPE" "$configuration_suffix"
 done

# Assemble the XCFramework
xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "$(pwd)/Carthage/archive" "$scheme" "$suffix" "$xcframework_sdks"
