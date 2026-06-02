#!/bin/bash
#
# Builds a SentryObjC-Static.xcframework locally.
#
# Orchestrates the per-SDK slice builds (sequentially) and then assembles
# the final xcframework. For CI, each slice runs as a separate parallel job;
# this script is the local equivalent that runs them in sequence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

OUTPUT_DIR="XCFrameworkBuildPath"
SDKS="iphoneos,iphonesimulator,macosx,maccatalyst,appletvos,appletvsimulator,watchos,watchsimulator,xros,xrsimulator"
PACKAGE_PATH=""
CONFIGURATION="Release"
VARIANT="static"

usage() {
    log_notice "Usage: $0"
    log_notice "  --output-dir <path>       Output directory (default: XCFrameworkBuildPath)"
    log_notice "  --configuration <name>    Xcode configuration (default: Release)"
    log_notice "  --sdks <list>             Comma-separated SDKs (default: all Apple SDKs)"
    log_notice "  --package-path <path>     Swift Package root (default: repo root)"
    log_notice "  --variant <type>          static, dynamic, or both (default: static)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)      OUTPUT_DIR="$2";     shift 2 ;;
        --configuration)   CONFIGURATION="$2";  shift 2 ;;
        --sdks)            SDKS="$2";           shift 2 ;;
        --package-path)    PACKAGE_PATH="$2";   shift 2 ;;
        --variant)         VARIANT="$2";        shift 2 ;;
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

rm -rf "$OUTPUT_DIR/archive/SentryObjC" "$OUTPUT_DIR/DerivedData" "$OUTPUT_DIR/lib/SentryObjC" "$OUTPUT_DIR/framework/SentryObjC"

PACKAGE_FILE="$PACKAGE_PATH/Package.swift"
cp "$PACKAGE_FILE" "$PACKAGE_FILE.bak"
trap 'mv "$PACKAGE_FILE.bak" "$PACKAGE_FILE"' EXIT
"$SCRIPT_DIR/prepare-package.sh" --package-file "$PACKAGE_FILE" --strip-binary-targets true

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
            --static-lib "$OUTPUT_DIR/lib/SentryObjC/$sdk/libSentryObjC.a" \
            --headers "$HEADERS_DIR" \
            --output-dir "$OUTPUT_DIR"
    done

    "$SCRIPT_DIR/assemble-xcframework-sentryobjc.sh" \
        --sdks "$SDKS" \
        --framework-path-template "$OUTPUT_DIR/framework/SentryObjC/SDK_NAME/SentryObjC.framework" \
        --output-name "SentryObjC-Dynamic"
    log_info "Done: SentryObjC-Dynamic.xcframework"
fi
