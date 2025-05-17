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

    declare pid_map

    for sdk in "${sdks[@]}"; do
        ./scripts/build-xcframework-slice.sh "$sdk" "$scheme" "$suffix" "$MACH_O_TYPE" "$configuration_suffix" &
        pid=$!
        pid_map[pid]="$sdk $scheme $suffix $MACH_O_TYPE $configuration_suffix"
    done

    for pid in "${!pid_map[@]}"; do
        if [ "$pid" -eq 0 ]; then
            unset "pid_map[$pid]"
        fi
    done

    echo "Waiting for ${!pid_map[*]}"

    for pid in "${!pid_map[@]}"; do
        wait "$pid"
        exit_status=$?
        if [ $exit_status -ne 0 ]; then
            echo "Process for ${pid_map[$pid]} failed with exit status $exit_status"
        else
            echo "Process for ${pid_map[$pid]} finished with PID $pid"
        fi
    done

    createxcframework+="-output Carthage/${scheme}${suffix}.xcframework"
    $createxcframework
}

echo "Generating Dynamic"
generate_xcframework "Sentry" "-Dynamic" &

if [ "$args" != "iOSOnly" ]; then
    echo "Generating staticlib"
    generate_xcframework "Sentry" "" staticlib &
    
    if [ "$args" != "gameOnly" ]; then
        echo "Generating SwiftUI"
        generate_xcframework "SentrySwiftUI" &
        echo "Generating WithoutUIKit"
        generate_xcframework "Sentry" "-WithoutUIKitOrAppKit" mh_dylib WithoutUIKit &
    fi
fi

wait
