#!/bin/bash
set -euo pipefail

# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(dirname "$0")/ci-utils.sh"

WORKSPACE=""
DERIVED_DATA=""
CONFIGURATION=""
PLATFORM=""

usage() {
    log_info "Usage: $0 --workspace <path> --derived-data <path> --configuration <name> --platform <platform>"
    log_info "Build and embed the unlinked V10 binary-image unload fixture in package test bundles."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace) WORKSPACE="$2"; shift 2 ;;
        --derived-data) DERIVED_DATA="$2"; shift 2 ;;
        --configuration) CONFIGURATION="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [[ -z "$WORKSPACE" || -z "$DERIVED_DATA" || -z "$CONFIGURATION" || -z "$PLATFORM" ]]; then
    usage
fi

ARCH=$(uname -m)
case "$PLATFORM" in
    macOS) SDK=macosx; TARGET="$ARCH-apple-macos12.0"; SUFFIX="" ;;
    Catalyst) SDK=macosx; TARGET="$ARCH-apple-ios15.0-macabi"; SUFFIX=-maccatalyst ;;
    iOS) SDK=iphonesimulator; TARGET="$ARCH-apple-ios15.0-simulator"; SUFFIX=-iphonesimulator ;;
    tvOS) SDK=appletvsimulator; TARGET="$ARCH-apple-tvos15.0-simulator"; SUFFIX=-appletvsimulator ;;
    visionOS) SDK=xrsimulator; TARGET="$ARCH-apple-xros1.0-simulator"; SUFFIX=-xrsimulator ;;
    watchOS) SDK=watchsimulator; TARGET="$ARCH-apple-watchos9.0-simulator"; SUFFIX=-watchsimulator ;;
    *) log_error "Unsupported fixture platform: $PLATFORM"; exit 1 ;;
esac

PRODUCTS="$DERIVED_DATA/Build/Products/$CONFIGURATION$SUFFIX"
# A target-only selector can build a wrapper suite without the main SDK suite.
if [[ ! -d "$PRODUCTS/SentryTests.xctest" ]]; then
    exit 0
fi

FRAMEWORKS="$PRODUCTS/SentryTests.xctest/Frameworks"
if [[ "$PLATFORM" == macOS || "$PLATFORM" == Catalyst ]]; then
    FRAMEWORKS="$PRODUCTS/SentryTests.xctest/Contents/Frameworks"
fi
FIXTURE="$FRAMEWORKS/SentryUnloadingImage.framework/SentryUnloadingImage"
mkdir -p "$(dirname "$FIXTURE")"
log_info "Building unlinked binary-image fixture for $PLATFORM"
xcrun --sdk "$SDK" clang -dynamiclib -target "$TARGET" \
    -isysroot "$(xcrun --sdk "$SDK" --show-sdk-path)" \
    "$WORKSPACE/Tests/Fixtures/UnloadingImage/image.c" -o "$FIXTURE"
