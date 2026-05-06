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
    # Build standalone SentryObjC xcframeworks (static + dynamic) that embed the full SDK.
    #
    # Strategy: build Sentry, SentryObjCTypes, SentryObjCBridge, and SentryObjC as
    # static frameworks, merge them with libtool, then assemble two xcframeworks —
    # one shipping the merged static archive directly, one re-linked as a dylib via
    # swiftc.
    #
    # The Sentry static framework is already built by StaticOnly above (or will be
    # built here if running SentryObjCOnly alone). We reuse those archives from
    # XCFrameworkBuildPath/archive/Sentry/.

    # 1. Build Sentry as a static framework if not already built
    if [ ! -d "XCFrameworkBuildPath/archive/Sentry" ]; then
        ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks" ""
    fi

    # 2. Build SentryObjCTypes as a static framework
    ./scripts/build-xcframework-variant.sh "SentryObjCTypes" "" "staticlib" "" "$sdks" ""

    # 3. Build SentryObjCBridge as a static framework
    ./scripts/build-xcframework-variant.sh "SentryObjCBridge" "" "staticlib" "" "$sdks" ""

    # 4. Build SentryObjC as a static framework
    ./scripts/build-xcframework-variant.sh "SentryObjC" "" "staticlib" "" "$sdks" ""

    # 5. Assemble both the static and dynamic standalone SentryObjC xcframeworks
    sdk_args=()
    case "$sdks" in
        AllSDKs)         for s in iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator; do sdk_args+=(--sdk "$s"); done ;;
        iOSOnly)         sdk_args=(--sdk iphoneos --sdk iphonesimulator) ;;
        macOSOnly)       sdk_args=(--sdk macosx) ;;
        macCatalystOnly) sdk_args=(--sdk maccatalyst) ;;
        *)               IFS=',' read -r -a sdk_list <<< "$sdks"; for s in "${sdk_list[@]}"; do sdk_args+=(--sdk "$s"); done ;;
    esac
    ./scripts/build-xcframework-sentryobjc-standalone.sh "${sdk_args[@]}"

    for linkage in Static Dynamic; do
        ./scripts/validate-xcframework-format.sh "SentryObjC-${linkage}.xcframework"
        ./scripts/compress-xcframework.sh "$signed" "SentryObjC-${linkage}"
        mv "SentryObjC-${linkage}.xcframework.zip" "XCFrameworkBuildPath/SentryObjC-${linkage}.xcframework.zip"
    done

    # Clean up intermediate static builds (keep Sentry/ — shared with StaticOnly)
    rm -rf "XCFrameworkBuildPath/archive/SentryObjCTypes"
    rm -rf "XCFrameworkBuildPath/archive/SentryObjCBridge"
    rm -rf "XCFrameworkBuildPath/archive/SentryObjC"
fi
