#!/bin/bash

set -eou pipefail

scheme="$1"
suffix="${2:-}"
MACH_O_TYPE="${3-mh_dylib}"
configuration_suffix="${4-}"
sdks_to_build="${5:-allSDKs}" # examples: allSDKs, ios, macosx, maccatalyst, tvos, watchos, visionos
verbose="${6:-}" # examples: --verbose)

if [ "${verbose:-}" = "--verbose" ]; then
    set -x
else
    set +x
fi
echo "--------------------------------"
echo "Building XCFramework ${scheme}${suffix} for ${sdks_to_build}"
echo "--------------------------------"

if [ "$sdks_to_build" = "ios" ]; then
    sdks=( iphoneos iphonesimulator )
elif [ "$sdks_to_build" = "tvos" ]; then
    sdks=( appletvos appletvsimulator )
elif [ "$sdks_to_build" = "watchos" ]; then
    sdks=( watchos watchsimulator )
elif [ "$sdks_to_build" = "visionos" ]; then
    sdks=( xros xrsimulator )
elif [ "$sdks_to_build" = "macosx" ]; then
    sdks=( macosx )
elif [ "$sdks_to_build" = "maccatalyst" ]; then
    sdks=( maccatalyst )
else
    sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

 for sdk in "${sdks[@]}"; do
     ./scripts/build-xcframework-slice.sh "$sdk" "$scheme" "$suffix" "$MACH_O_TYPE" "$configuration_suffix"
 done

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "$scheme" "$suffix" "$configuration_suffix" "$xcframework_sdks" "$(pwd)/Carthage/archive/$scheme$suffix/SDK_NAME.xcarchive"
