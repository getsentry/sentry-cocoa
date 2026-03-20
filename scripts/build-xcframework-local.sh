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
    # Strategy: build Sentry, SentryObjCBridge, and SentryObjC as static
    # frameworks, merge them with libtool, then link into a dynamic library
    # with swiftc. This produces a single binary containing wrapper + bridge
    # + full SDK + Swift runtime.
    #
    # The Sentry static framework is already built by StaticOnly above
    # (or will be built here if running SentryObjCOnly alone). We reuse
    # those archives from XCFrameworkBuildPath/archive/Sentry/.

    # 1. Build Sentry as a static framework if not already built
    if [ ! -d "XCFrameworkBuildPath/archive/Sentry" ]; then
        ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks" ""
    fi

    # 2. Build SentryObjCBridge as a static framework
    ./scripts/build-xcframework-variant.sh "SentryObjCBridge" "" "staticlib" "" "$sdks" ""

    # 3. Build SentryObjC as a static framework
    ./scripts/build-xcframework-variant.sh "SentryObjC" "" "staticlib" "" "$sdks" ""

    # 4. Link all three static archives into a standalone dynamic SentryObjC framework
    ./scripts/build-xcframework-sentryobjc-standalone.sh "$sdks"

    ./scripts/validate-xcframework-format.sh "SentryObjC.xcframework"
    ./scripts/compress-xcframework.sh "$signed" SentryObjC
    mv SentryObjC.xcframework.zip XCFrameworkBuildPath/SentryObjC.xcframework.zip

    # Clean up intermediate static builds (keep Sentry/ — shared with StaticOnly)
    rm -rf "XCFrameworkBuildPath/archive/SentryObjCBridge"
    rm -rf "XCFrameworkBuildPath/archive/SentryObjC"
fi
