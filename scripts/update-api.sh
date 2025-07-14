#!/bin/bash
set -euo pipefail

configuration_suffix="${1-}"

./scripts/build-xcframework-slice.sh "iphoneos" "Sentry" "-Dynamic" "mh_dylib" "$configuration_suffix"

./scripts/assemble-xcframework.sh "Sentry" "-Dynamic" "" "iphoneos" "$(pwd)/Carthage/archive/Sentry-Dynamic/SDK_NAME.xcarchive"

# Delete private .swiftinterface files before running swift-api-digester
# This ensures only public interfaces are analyzed
find ./Sentry-Dynamic.xcframework -name "*.private.swiftinterface" -type f -delete

xcrun --sdk iphoneos swift-api-digester \
    -dump-sdk \
    -o sdk_api${configuration_suffix:+"_${configuration_suffix}"}.json \
    -abort-on-module-fail \
    -avoid-tool-args \
    -avoid-location \
    -module Sentry \
    -target arm64-apple-ios10.0 \
    -iframework ./Sentry-Dynamic.xcframework/ios-arm64_arm64e
