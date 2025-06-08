#!/bin/bash

set -eoux pipefail

sdks="${1:-all}" # examples: all, ios, macosx, maccatalyst, tvos, watchos, visionos
variants="${2:-all}" # examples: all, dynamic, static, swiftui, withoutUIKit
signed="${3:-}"

mkdir -p Carthage

if [ "$variants" = "dynamic" ] || [ "$variants" = "all" ]; then
    final_zip_path="Carthage/Sentry-Dynamic.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic
    mv Sentry-Dynamic.xcframework.zip "$final_zip_path"
fi

if [ "$variants" = "static" ] || [ "$variants" = "all" ]; then
    final_zip_path="Carthage/Sentry.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" Sentry
    mv Sentry.xcframework.zip "$final_zip_path"
fi

if [ "$variants" = "swiftui" ] || [ "$variants" = "all" ]; then
    final_zip_path="Carthage/SentrySwiftUI.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "mh_dylib" "" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" SentrySwiftUI
    mv SentrySwiftUI.xcframework.zip "$final_zip_path"fi

if [ "$variants" = "withoutUIKit" ] || [ "$variants" = "all" ]; then
    final_zip_path="Carthage/Sentry-WithoutUIKitOrAppKit.xcframework.zip"
    rm -rf "$final_zip_path"
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$sdks"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit
    mv Sentry-WithoutUIKitOrAppKit.xcframework.zip "$final_zip_path"fi
