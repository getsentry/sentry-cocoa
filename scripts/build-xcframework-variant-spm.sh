#!/bin/bash
# Build SwiftPM SDK slices and assemble a self-contained dynamic XCFramework.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./tools.sh disable=SC1091
source "$SCRIPT_DIR/tools.sh"

PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
SDKS=""
OUTPUT_DIR="$PACKAGE_PATH/XCFrameworkBuildPath/SPM"

usage() {
    log_info "Usage: $0 [options]"
    log_info "  -d, --sdks <list>        Comma-separated SDKs or AllSDKs, iOSOnly, macOSOnly, macCatalystOnly (default: all)"
    log_info "  -o, --output-dir <path>  Build directory (default: <repo>/XCFrameworkBuildPath/SPM)"
    log_info "Set SDK_V10=1 to build V10 instead of V9."
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ "$1" != -h && "$1" != --help ]] && [[ $# -lt 2 || "$2" == --* ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case $1 in
        -d|--sdks) SDKS="$2"; shift 2 ;;
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$OUTPUT_DIR" ]; then
    log_error "--output-dir must not be empty"
    usage
fi

case "$SDKS" in
    ""|AllSDKs) sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator ) ;;
    iOSOnly) sdks=( iphoneos iphonesimulator ) ;;
    macOSOnly) sdks=( macosx ) ;;
    macCatalystOnly) sdks=( maccatalyst ) ;;
    *) IFS=',' read -r -a sdks <<< "$SDKS" ;;
esac

version="$(read_xcconfig_value_or_exit \
    --key MARKETING_VERSION \
    --file "$PACKAGE_PATH/Sources/Configuration/Versioning.xcconfig")"
scheme=SentrySPM
if [ "${SDK_V10:-0}" = 1 ]; then scheme=Sentry; fi
framework_name=SentrySwift
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

for sdk in "${sdks[@]}"; do
    "$SCRIPT_DIR/build-static-library.sh" \
        --sdk "$sdk" \
        --scheme "$scheme" \
        --architecture-target "$framework_name" \
        --package-path "$PACKAGE_PATH" \
        --configuration Release \
        --output-dir "$OUTPUT_DIR"
    prepared="$OUTPUT_DIR/prepared/$sdk"
    "$SCRIPT_DIR/prepare-sentry-framework-inputs.sh" \
        --swift-archive "$OUTPUT_DIR/archive/$scheme/$sdk.xcarchive" \
        --headers "$PACKAGE_PATH/Sources/Sentry/Public" \
        --framework-name "$framework_name" \
        --output-dir "$prepared"
    "$SCRIPT_DIR/build-dynamic-framework.sh" \
        --sdk "$sdk" \
        --framework-name "$framework_name" \
        --version "$version" \
        --output-dir "$OUTPUT_DIR" \
        --static-lib "$OUTPUT_DIR/lib/$scheme/$sdk/lib$scheme-Debug.a" \
        --headers "$prepared/Headers" \
        --modules "$prepared/Modules" \
        --resources "$prepared/Resources"
done

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
"$SCRIPT_DIR/assemble-xcframework.sh" \
    --sdks "$xcframework_sdks" \
    --framework-template "$OUTPUT_DIR/framework/$framework_name/SDK_NAME/$framework_name.framework" \
    --output "$OUTPUT_DIR/$framework_name.xcframework" \
    --require-debug-symbols
