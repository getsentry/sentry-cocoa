#!/bin/bash
set -euo pipefail

./scripts/build-xcframework.sh iOSOnly

xcrun --sdk iphoneos swift-api-digester \
    -dump-sdk \
    -o sdk_api.json \
    -abort-on-module-fail \
    -avoid-tool-args \
    -avoid-location \
    -module Sentry \
    -target arm64-apple-ios10.0 \
    -iframework ./Carthage/Sentry-Dynamic.xcframework/ios-arm64_arm64e
