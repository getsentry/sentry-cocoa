#!/bin/bash

set -eoux pipefail

sdks="${1:-AllSDKs}"
variants="${2:-AllVariants}"
signed="${3:-}"

rm -rf SentryOutput/
mkdir SentryOutput

if [ "$variants" = "DynamicOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$sdks" "arm64e"
    ./scripts/validate-xcframework-format.sh "Sentry-Dynamic.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic
    mv Sentry-Dynamic.xcframework.zip SentryOutput/Sentry-Dynamic.xcframework.zip
fi

if [ "$variants" = "DynamicWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic-WithARM64e" "mh_dylib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry-Dynamic-WithARM64e.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic-WithARM64e
    mv Sentry-Dynamic-WithARM64e.xcframework.zip SentryOutput/Sentry-Dynamic-WithARM64e.xcframework.zip
fi

if [ "$variants" = "StaticOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry
    mv Sentry.xcframework.zip SentryOutput/Sentry.xcframework.zip
fi

if [ "$variants" = "SwiftUIOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "mh_dylib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "SentrySwiftUI.xcframework"
    ./scripts/compress-xcframework.sh "$signed" SentrySwiftUI
    mv SentrySwiftUI.xcframework.zip SentryOutput/SentrySwiftUI.xcframework.zip
fi

if [ "$variants" = "WithoutUIKitOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$sdks" "arm64e"
    ./scripts/validate-xcframework-format.sh "Sentry-WithoutUIKitOrAppKit.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit
    mv Sentry-WithoutUIKitOrAppKit.xcframework.zip SentryOutput/Sentry-WithoutUIKitOrAppKit.xcframework.zip
fi

if [ "$variants" = "WithoutUIKitWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit-WithARM64e" "mh_dylib" "WithoutUIKit" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit-WithARM64e
    mv Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip SentryOutput/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip
fi
