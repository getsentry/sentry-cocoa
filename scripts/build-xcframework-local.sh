#!/bin/bash

set -eoux pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [sdks] [variants] [signed]

Build, validate, and compress XCFramework variants locally.

ARGUMENTS:
    sdks        Comma-separated SDK list or 'AllSDKs' (default: AllSDKs)
    variants    Which variant(s) to build (default: AllVariants)
                  AllVariants | DynamicOnly | DynamicWithARM64eOnly |
                  StaticOnly | SwiftUIOnly | WithoutUIKitOnly |
                  WithoutUIKitWithARM64eOnly
    signed      Signing identity (default: unsigned)

EXAMPLES:
    $(basename "$0")
    $(basename "$0") AllSDKs DynamicOnly
    $(basename "$0") "iphoneos,macosx" AllVariants "Apple Distribution: ..."

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

sdks="${1:-AllSDKs}"
variants="${2:-AllVariants}"
signed="${3:-}"

log_info "Building XCFrameworks: sdks=$sdks variants=$variants signed=${signed:-unsigned}"

rm -rf XCFrameworkBuildPath/
mkdir XCFrameworkBuildPath

if [ "$variants" = "DynamicOnly" ] || [ "$variants" = "AllVariants" ]; then
    begin_group "Sentry-Dynamic"
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic" "mh_dylib" "" "$sdks" "arm64e"
    ./scripts/validate-xcframework-format.sh "Sentry-Dynamic.xcframework"
    ./scripts/validate-xcframework-architectures.sh --xcframework "Sentry-Dynamic.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic
    mv Sentry-Dynamic.xcframework.zip XCFrameworkBuildPath/Sentry-Dynamic.xcframework.zip
    end_group
fi

if [ "$variants" = "DynamicWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    begin_group "Sentry-Dynamic-WithARM64e"
    ./scripts/build-xcframework-variant.sh "Sentry" "-Dynamic-WithARM64e" "mh_dylib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry-Dynamic-WithARM64e.xcframework"
    ./scripts/validate-xcframework-architectures.sh --xcframework "Sentry-Dynamic-WithARM64e.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-Dynamic-WithARM64e
    mv Sentry-Dynamic-WithARM64e.xcframework.zip XCFrameworkBuildPath/Sentry-Dynamic-WithARM64e.xcframework.zip
    end_group
fi

if [ "$variants" = "StaticOnly" ] || [ "$variants" = "AllVariants" ]; then
    begin_group "Sentry-Static"
    ./scripts/build-xcframework-variant.sh "Sentry" "" "staticlib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry.xcframework"
    ./scripts/validate-xcframework-architectures.sh --xcframework "Sentry.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry
    mv Sentry.xcframework.zip XCFrameworkBuildPath/Sentry.xcframework.zip
    end_group
fi

if [ "$variants" = "SwiftUIOnly" ] || [ "$variants" = "AllVariants" ]; then
    begin_group "SentrySwiftUI"
    ./scripts/build-xcframework-variant.sh "SentrySwiftUI" "" "mh_dylib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "SentrySwiftUI.xcframework"
    ./scripts/validate-xcframework-architectures.sh --xcframework "SentrySwiftUI.xcframework"
    ./scripts/compress-xcframework.sh "$signed" SentrySwiftUI
    mv SentrySwiftUI.xcframework.zip XCFrameworkBuildPath/SentrySwiftUI.xcframework.zip
    end_group
fi

if [ "$variants" = "WithoutUIKitOnly" ] || [ "$variants" = "AllVariants" ]; then
    begin_group "Sentry-WithoutUIKitOrAppKit"
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit" "mh_dylib" "WithoutUIKit" "$sdks" "arm64e"
    ./scripts/validate-xcframework-format.sh "Sentry-WithoutUIKitOrAppKit.xcframework"
    ./scripts/validate-xcframework-architectures.sh --xcframework "Sentry-WithoutUIKitOrAppKit.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit
    mv Sentry-WithoutUIKitOrAppKit.xcframework.zip XCFrameworkBuildPath/Sentry-WithoutUIKitOrAppKit.xcframework.zip
    end_group
fi

if [ "$variants" = "WithoutUIKitWithARM64eOnly" ] || [ "$variants" = "AllVariants" ]; then
    begin_group "Sentry-WithoutUIKitOrAppKit-WithARM64e"
    ./scripts/build-xcframework-variant.sh "Sentry" "-WithoutUIKitOrAppKit-WithARM64e" "mh_dylib" "WithoutUIKit" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework"
    ./scripts/validate-xcframework-architectures.sh --xcframework "Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework"
    ./scripts/compress-xcframework.sh "$signed" Sentry-WithoutUIKitOrAppKit-WithARM64e
    mv Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip XCFrameworkBuildPath/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip
    end_group
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
        ./scripts/validate-xcframework-architectures.sh --xcframework "SentryObjC-${linkage}.xcframework"
        ./scripts/compress-xcframework.sh "$signed" "SentryObjC-${linkage}"
        mv "SentryObjC-${linkage}.xcframework.zip" "XCFrameworkBuildPath/SentryObjC-${linkage}.xcframework.zip"
    done

    # Clean up intermediate static builds (keep Sentry/ — shared with StaticOnly)
    rm -rf "XCFrameworkBuildPath/archive/SentryObjCTypes"
    rm -rf "XCFrameworkBuildPath/archive/SentryObjCBridge"
    rm -rf "XCFrameworkBuildPath/archive/SentryObjC"
fi
