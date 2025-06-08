#!/bin/bash

set -eou pipefail

sdks="${1:-allSDKs}" # examples: allSDKs, ios, macosx, maccatalyst, tvos, watchos, visionos
variants="${2:-allVariants}" # examples: allVariants, dynamic, static, swiftui, withoutUIKit
signed="${3:-}" # examples: --sign, --no-sign (anything other than --sign is considered no-sign)

echo "--------------------------------"
echo "Building XCFramework variant ${variants} for ${sdks}"
echo "--------------------------------"

mkdir -p Carthage

if [ "$variants" = "dynamic" ] || [ "$variants" = "allVariants" ]; then
    final_zip_path="Carthage/Sentry-Dynamic.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic
    mv Sentry-Dynamic.xcframework.zip "$final_zip_path"
fi

if [ "$variants" = "static" ] || [ "$variants" = "allVariants" ]; then
    final_zip_path="Carthage/Sentry.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" Sentry
    mv Sentry.xcframework.zip "$final_zip_path"
fi

if [ "$variants" = "swiftui" ] || [ "$variants" = "allVariants" ]; then
    final_zip_path="Carthage/SentrySwiftUI.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "mh_dylib" "" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" SentrySwiftUI
    mv SentrySwiftUI.xcframework.zip "$final_zip_path"fi

if [ "$variants" = "withoutUIKit" ] || [ "$variants" = "allVariants" ]; then
    final_zip_path="Carthage/Sentry-WithoutUIKitOrAppKit.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit
    mv Sentry-WithoutUIKitOrAppKit.xcframework.zip "$final_zip_path"fi
