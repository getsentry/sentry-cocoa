#!/bin/bash

set -eoux pipefail

sdks="${1:-AllSDKs}"
variants="${2:-AllVariants}"
signed="${3:-}"

rm -rf Carthage/
mkdir Carthage

if [ "$variants" = "DynamicOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$sdks" "arm64e"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic
    mv Sentry-Dynamic.xcframework.zip Carthage/Sentry-Dynamic.xcframework.zip
fi

if [ "$variants" = "DynamicWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic-WithARM64e" "mh_dylib" "" "$sdks" ""
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic-WithARM64e
    mv Sentry-Dynamic-WithARM64e.xcframework.zip Carthage/Sentry-Dynamic-WithARM64e.xcframework.zip
fi

if [ "$variants" = "StaticOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks" ""
    ./scripts/compress-xcframework.sh "$signed" Sentry
    mv Sentry.xcframework.zip Carthage/Sentry.xcframework.zip
fi

if [ "$variants" = "SwiftUIOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "mh_dylib" "" "$sdks" ""
    ./scripts/compress-xcframework.sh "$signed" SentrySwiftUI
    mv SentrySwiftUI.xcframework.zip Carthage/SentrySwiftUI.xcframework.zip
fi

if [ "$variants" = "WithoutUIKitOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$sdks" ""
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit
    mv Sentry-WithoutUIKitOrAppKit.xcframework.zip Carthage/Sentry-WithoutUIKitOrAppKit.xcframework.zip
fi

if [ "$variants" = "WithoutUIKitWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit-WithARM64e" "mh_dylib" "WithoutUIKit" "$sdks" "arm64e"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit-WithARM64e
    mv Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip Carthage/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip
fi
