#!/bin/bash

set -eoux pipefail

scheme="$1"
suffix="${2:-}"
MACH_O_TYPE="${3-mh_dylib}"
configuration_suffix="${4-}"
sdks_to_build="${5:-}"
excluded_archs="${6:-}"

if [ "$sdks_to_build" = "iOSOnly" ]; then
    sdks=( iphoneos iphonesimulator )
elif [ "$sdks_to_build" = "macOSOnly" ]; then
    sdks=( macosx )
elif [ "$sdks_to_build" = "macCatalystOnly" ]; then
    sdks=( maccatalyst )
else
    sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

for sdk in "${sdks[@]}"; do
    ./scripts/build-xcframework-slice.sh "$sdk" "$scheme" "$suffix" "$MACH_O_TYPE" "$configuration_suffix"
done

if [ -n "$excluded_archs" ]; then
    ./scripts/remove-architectures.sh "$(pwd)/Carthage/archive/$scheme$suffix/" "$excluded_archs"
fi

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "$scheme" "$suffix" "$configuration_suffix" "$xcframework_sdks" "$(pwd)/Carthage/archive/$scheme$suffix/SDK_NAME.xcarchive"
