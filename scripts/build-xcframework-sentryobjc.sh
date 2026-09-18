#!/bin/bash
#
# Builds a SentryObjC-Static.xcframework locally.
#
# Orchestrates the per-SDK slice builds (sequentially) and then assembles
# the final xcframework. For CI, each slice runs as a separate parallel job;
# this script is the local equivalent that runs them in sequence.
#
# With --v10 the package is built with SDK_V10=1, which swaps SentryCrash for
# KSCrash and embeds the KSCrash objects into the library. The packaged headers
# are copies with every SDK_V10 gate resolved, so consumers see the V10 API
# without defining SDK_V10 themselves. V10 output is meant for local debugging
# of downstream SDKs and is not a release artifact.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

OUTPUT_DIR="XCFrameworkBuildPath"
SDKS="iphoneos,iphonesimulator,macosx,maccatalyst,appletvos,appletvsimulator,watchos,watchsimulator,xros,xrsimulator"
PACKAGE_PATH=""
CONFIGURATION="Release"
VARIANT="static"
V10="false"

usage() {
    log_notice "Usage: $0"
    log_notice "  --output-dir <path>       Output directory (default: XCFrameworkBuildPath)"
    log_notice "  --configuration <name>    Xcode configuration (default: Release)"
    log_notice "  --sdks <list>             Comma-separated SDKs (default: all Apple SDKs)"
    log_notice "  --package-path <path>     Swift Package root (default: repo root)"
    log_notice "  --variant <type>          static, dynamic, or both (default: static)"
    log_notice "  --v10                     Build the V10 (KSCrash) SDK for local debugging"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)      OUTPUT_DIR="$2";     shift 2 ;;
        --configuration)   CONFIGURATION="$2";  shift 2 ;;
        --sdks)            SDKS="$2";           shift 2 ;;
        --package-path)    PACKAGE_PATH="$2";   shift 2 ;;
        --variant)         VARIANT="$2";        shift 2 ;;
        --v10)             V10="true";          shift ;;
        -h|--help)         usage ;;
        *)                 log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$PACKAGE_PATH" ]; then
    PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

HEADERS_DIR="$PACKAGE_PATH/Sources/SentryObjC/Public"

if [ ! -d "$HEADERS_DIR" ]; then
    log_error "Public headers directory not found at $HEADERS_DIR"
    exit 1
fi

case "$VARIANT" in
    static|dynamic|both) ;;
    *) log_error "Unknown variant: $VARIANT (expected static, dynamic, or both)"; exit 1 ;;
esac

if [ -z "$SDKS" ] || [ "$SDKS" = "AllSDKs" ]; then
    SDKS="iphoneos,iphonesimulator,macosx,maccatalyst,appletvos,appletvsimulator,watchos,watchsimulator,xros,xrsimulator"
fi

if [ "$V10" = "true" ]; then
    # Package.swift reads SDK_V10 from the environment of every xcodebuild invocation below.
    export SDK_V10=1

    # The public headers gate V10-only and V9-only API with SDK_V10. Resolve the gates so the
    # packaged headers match the binary; consumers such as bindings generators do not define it.
    V10_HEADERS_DIR="$OUTPUT_DIR/headers/SentryObjC-V10"
    rm -rf "$V10_HEADERS_DIR"
    mkdir -p "$V10_HEADERS_DIR"
    for header in "$HEADERS_DIR"/*.h; do
        # unifdef exits with 1 when it changed the file and with 2 on errors.
        unifdef -DSDK_V10=1 -o "$V10_HEADERS_DIR/$(basename "$header")" "$header" || [ $? -eq 1 ]
    done
    HEADERS_DIR="$V10_HEADERS_DIR"
    log_info "Building V10 with resolved headers at $HEADERS_DIR"
fi

rm -rf "$OUTPUT_DIR/archive/SentryObjC" "$OUTPUT_DIR/DerivedData" "$OUTPUT_DIR/lib/SentryObjC" "$OUTPUT_DIR/framework/SentryObjC"

PACKAGE_FILES=()
for f in "$PACKAGE_PATH"/Package.swift "$PACKAGE_PATH"/Package@swift-*.swift; do
    [ -f "$f" ] && PACKAGE_FILES+=("$f")
done

for f in "${PACKAGE_FILES[@]}"; do
    cp "$f" "$f.bak"
done
trap 'for f in "${PACKAGE_FILES[@]}"; do mv "$f.bak" "$f"; done' EXIT

"$SCRIPT_DIR/prepare-package.sh" --strip-binary-targets true

IFS=',' read -r -a sdk_list <<< "$SDKS"

for sdk in "${sdk_list[@]}"; do
    "$SCRIPT_DIR/build-static-library-sentryobjc.sh" \
        --sdk "$sdk" \
        --output-dir "$OUTPUT_DIR" \
        --package-path "$PACKAGE_PATH" \
        --configuration "$CONFIGURATION"
done

if [ "$VARIANT" = "static" ] || [ "$VARIANT" = "both" ]; then
    "$SCRIPT_DIR/assemble-xcframework-sentryobjc.sh" \
        --sdks "$SDKS" \
        --lib-path-template "$OUTPUT_DIR/lib/SentryObjC/SDK_NAME/libSentryObjC.a" \
        --headers "$HEADERS_DIR" \
        --output-name "SentryObjC-Static"
    log_info "Done: SentryObjC-Static.xcframework"
fi

if [ "$VARIANT" = "dynamic" ] || [ "$VARIANT" = "both" ]; then
    for sdk in "${sdk_list[@]}"; do
        "$SCRIPT_DIR/build-dynamic-framework-sentryobjc.sh" \
            --sdk "$sdk" \
            --static-lib "$OUTPUT_DIR/lib/SentryObjC/$sdk/libSentryObjC-Debug.a" \
            --headers "$HEADERS_DIR" \
            --output-dir "$OUTPUT_DIR"
    done

    "$SCRIPT_DIR/assemble-xcframework-sentryobjc.sh" \
        --sdks "$SDKS" \
        --framework-path-template "$OUTPUT_DIR/framework/SentryObjC/SDK_NAME/SentryObjC.framework" \
        --output-name "SentryObjC-Dynamic"
    log_info "Done: SentryObjC-Dynamic.xcframework"
fi
