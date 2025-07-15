#!/bin/bash
set -euo pipefail

configuration_suffix="${1-}"

./scripts/build-xcframework-slice.sh "iphoneos" "Sentry" "-Dynamic" "mh_dylib" "$configuration_suffix"

./scripts/assemble-xcframework.sh "Sentry" "-Dynamic" "" "iphoneos" "$(pwd)/Carthage/archive/Sentry-Dynamic/SDK_NAME.xcarchive"

# Delete private .swiftinterface files before running swift-api-digester
# This ensures only public interfaces are analyzed
find ./Sentry-Dynamic.xcframework -name "*.private.swiftinterface" -type f -delete

if [ "$configuration_suffix" = "V9" ]; then
  FWROOT="./Sentry-Dynamic.xcframework/ios-arm64_arm64e/Sentry.framework"
  for FRAME in Headers PrivateHeaders; do
    HDRDIR="$FWROOT/${FRAME}"
    for H in "$HDRDIR"/*.h; do
      # unifdef will:
      #  - keep code under #if SDK_V9 (because of -D)
      #  - remove code under #else
      #  - strip away the #if/#else/#endif lines themselves
      unifdef -D SDK_V9 -x 2 "$H" > "$H.tmp"
      mv "$H.tmp" "$H"
    done
  done
fi

xcrun --sdk iphoneos swift-api-digester \
    -dump-sdk \
    -o sdk_api${configuration_suffix:+"_${configuration_suffix}"}.json \
    -abort-on-module-fail \
    -avoid-tool-args \
    -avoid-location \
    -module Sentry \
    -target arm64-apple-ios10.0 \
    -iframework ./Sentry-Dynamic.xcframework/ios-arm64_arm64e
