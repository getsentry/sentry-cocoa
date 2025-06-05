#!/bin/bash

set -eoux pipefail

scheme="$1"
suffix="${2:-}"
MACH_O_TYPE="${3-mh_dylib}"
configuration_suffix="${4-}"
args="${5:-}"

if [ "$args" = "iOSOnly" ]; then
    sdks=( iphoneos iphonesimulator )
else
    sdks=( iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

 for sdk in "${sdks[@]}"; do
     ./scripts/build-xcframework-slice.sh "$sdk" "$scheme" "$suffix" "$MACH_O_TYPE" "$configuration_suffix"
 done

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "$(pwd)/Carthage/archive" "$scheme" "$suffix" "$xcframework_sdks"
