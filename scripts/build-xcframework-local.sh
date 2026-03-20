#!/bin/bash

set -eoux pipefail

sdks="${1:-AllSDKs}"
variants="${2:-AllVariants}"
signed="${3:-}"

rm -rf XCFrameworkBuildPath/
mkdir XCFrameworkBuildPath

if [ "$variants" = "DynamicOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$sdks" "arm64e"
    ./scripts/validate-xcframework-format.sh "Sentry-Dynamic.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic
    mv Sentry-Dynamic.xcframework.zip XCFrameworkBuildPath/Sentry-Dynamic.xcframework.zip
fi

if [ "$variants" = "DynamicWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic-WithARM64e" "mh_dylib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry-Dynamic-WithARM64e.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic-WithARM64e
    mv Sentry-Dynamic-WithARM64e.xcframework.zip XCFrameworkBuildPath/Sentry-Dynamic-WithARM64e.xcframework.zip
fi

if [ "$variants" = "StaticOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry
    mv Sentry.xcframework.zip XCFrameworkBuildPath/Sentry.xcframework.zip
fi

if [ "$variants" = "SwiftUIOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "mh_dylib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "SentrySwiftUI.xcframework"
    ./scripts/compress-xcframework.sh "$signed" SentrySwiftUI
    mv SentrySwiftUI.xcframework.zip XCFrameworkBuildPath/SentrySwiftUI.xcframework.zip
fi

if [ "$variants" = "WithoutUIKitOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$sdks" "arm64e"
    ./scripts/validate-xcframework-format.sh "Sentry-WithoutUIKitOrAppKit.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit
    mv Sentry-WithoutUIKitOrAppKit.xcframework.zip XCFrameworkBuildPath/Sentry-WithoutUIKitOrAppKit.xcframework.zip
fi

if [ "$variants" = "WithoutUIKitWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit-WithARM64e" "mh_dylib" "WithoutUIKit" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit-WithARM64e
    mv Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip XCFrameworkBuildPath/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip
fi

if [ "$variants" = "SentryObjCOnly" ] || [ "$variants" = "AllVariants" ]; then
    # Build a standalone SentryObjC.xcframework that embeds the full SDK.
    #
    # Strategy: build Sentry and SentryObjCBridge as static frameworks first,
    # then build SentryObjC as a dynamic framework with FRAMEWORK_SEARCH_PATHS
    # pointing at those static frameworks. Xcode's link phase resolves
    # -framework Sentry and -framework SentryObjCBridge to the static binaries,
    # embedding all symbols into the single SentryObjC binary. No force_load,
    # no duplicate symbols, and Xcode handles all system framework flags.

    # 1. Build Sentry as a static framework (for embedding)
    ./scripts/build-xcframework-variant.sh "Sentry" "-ForEmbedding" "staticlib" "" "$sdks" ""

    # 2. Build SentryObjCBridge as a static framework (for embedding)
    ./scripts/build-xcframework-variant.sh "SentryObjCBridge" "-ForEmbedding" "staticlib" "" "$sdks" ""

    # 3. Build SentryObjC as static (just its own .m files)
    ./scripts/build-xcframework-variant.sh "SentryObjC" "-ForEmbedding" "staticlib" "" "$sdks" ""

    # 4. Link all three static archives into a standalone dynamic SentryObjC framework
    ./scripts/build-xcframework-sentryobjc-standalone.sh "$sdks"

    ./scripts/validate-xcframework-format.sh "SentryObjC.xcframework"
    ./scripts/compress-xcframework.sh "$signed" SentryObjC
    mv SentryObjC.xcframework.zip XCFrameworkBuildPath/SentryObjC.xcframework.zip

    # Clean up intermediate static builds
    rm -rf "XCFrameworkBuildPath/archive/Sentry-ForEmbedding"
    rm -rf "XCFrameworkBuildPath/archive/SentryObjCBridge-ForEmbedding"
    rm -rf "XCFrameworkBuildPath/archive/SentryObjC-ForEmbedding"
fi
