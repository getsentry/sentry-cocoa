#!/bin/bash

set -eoux pipefail

sdks="${1:-AllSDKs}"
variants="${2:-AllVariants}"
signed="${3:-}"

rm -rf Carthage/
mkdir Carthage

if [ "$variants" = "DynamicOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$sdks"
    ./scripts/zip_built_sdk.sh "$signed" Sentry-Dynamic
fi

if [ "$variants" = "StaticOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks"
    ./scripts/zip_built_sdk.sh "$signed" Sentry
fi

if [ "$variants" = "SwiftUIOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "mh_dylib" "" "$sdks"
    ./scripts/zip_built_sdk.sh "$signed" SentrySwiftUI
fi

if [ "$variants" = "WithoutUIKitOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$sdks"
    ./scripts/zip_built_sdk.sh "$signed" Sentry-WithoutUIKitOrAppKit
fi
