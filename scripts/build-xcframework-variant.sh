#!/bin/bash
#
# Builds all slices for an XCFramework variant
#
# Parameters:
#   $1 - scheme (e.g., Sentry, SentryObjC)
#   $2 - suffix (optional, e.g., -Dynamic)
#   $3 - MACH_O_TYPE (mh_dylib or staticlib)
#   $4 - configuration_suffix (optional)
#   $5 - sdks_to_build (AllSDKs, iOSOnly, macOSOnly, macCatalystOnly)
#   $6 - excluded_archs (optional)
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
elif [ -z "$sdks_to_build" ] || [ "$sdks_to_build" = "AllSDKs" ]; then
    sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
else
    # Treat as comma-separated list (e.g. "iphonesimulator" or "iphoneos,iphonesimulator").
    IFS=',' read -r -a sdks <<< "$sdks_to_build"
fi

for sdk in "${sdks[@]}"; do
    ./scripts/build-xcframework-slice.sh "$sdk" "$scheme" "$suffix" "$MACH_O_TYPE" "$configuration_suffix"
done

if [ -n "$excluded_archs" ]; then
    ./scripts/remove-architectures.sh "$(pwd)/XCFrameworkBuildPath/archive/$scheme$suffix/" "$excluded_archs"
fi

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "$scheme" "$suffix" "$configuration_suffix" "$xcframework_sdks" "$(pwd)/XCFrameworkBuildPath/archive/$scheme$suffix/SDK_NAME.xcarchive"
