#!/bin/bash

set -eoux pipefail

args="${1:-}"

rm -rf Carthage/
mkdir Carthage

./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$args"

if [ "$args" = "iOSOnly" ]; then
    exit 0
fi

./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$args"
./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "" "" "$args"
./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$args"
