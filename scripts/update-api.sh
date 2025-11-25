#!/bin/bash
set -euo pipefail

# Check if Xcode 16 is selected
XCODE_VERSION=$(xcodebuild -version | head -n 1 | awk '{print $2}')
XCODE_MAJOR_VERSION=$(echo "$XCODE_VERSION" | cut -d. -f1)

if [[ "$XCODE_MAJOR_VERSION" != "16" ]]; then
    echo "Error: Xcode 16 is required for running the update-api.sh script, because Xcode 26 doesn't include the ObjC public API, but Xcode $XCODE_VERSION is currently selected."
    echo "Please select Xcode 16 using 'sudo xcode-select' or 'xcodes select 16.x'"
    exit 1
fi

./scripts/build-xcframework-slice.sh "iphoneos" "Sentry" "-Dynamic" "mh_dylib"

./scripts/assemble-xcframework.sh "Sentry" "-Dynamic" "" "iphoneos" "$(pwd)/Carthage/archive/Sentry-Dynamic/SDK_NAME.xcarchive"

# Delete private .swiftinterface files before running swift-api-digester
# This ensures only public interfaces are analyzed
find ./Sentry-Dynamic.xcframework -name "*.private.swiftinterface" -type f -delete

xcrun --sdk iphoneos swift-api-digester \
    -dump-sdk \
    -o sdk_api.json \
    -abort-on-module-fail \
    -avoid-tool-args \
    -avoid-location \
    -module Sentry \
    -target arm64-apple-ios10.0 \
    -iframework ./Sentry-Dynamic.xcframework/ios-arm64_arm64e
