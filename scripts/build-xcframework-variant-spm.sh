#!/bin/bash
# Build SwiftPM SDK slices and assemble a self-contained dynamic XCFramework.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./tools.sh disable=SC1091
source "$SCRIPT_DIR/tools.sh"
# shellcheck source=./xcframework-utils.sh disable=SC1091
source "$SCRIPT_DIR/xcframework-utils.sh"

PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
SDKS=""
variant=Sentry-Dynamic
OUTPUT_DIR="$PACKAGE_PATH/XCFrameworkBuildPath/SPM"

usage() {
    log_info "Usage: $0 [options]"
    log_info "  -v, --variant <name>     Shipping artifact basename: Sentry-Dynamic or Sentry-Dynamic-WithARM64e (default: Sentry-Dynamic)"
    log_info "  -d, --sdks <list>        Comma-separated SDKs or AllSDKs, iOSOnly, macOSOnly, macCatalystOnly (default: all)"
    log_info "  -o, --output-dir <path>  Build directory (default: <repo>/XCFrameworkBuildPath/SPM)"
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
        -v|--variant) variant="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$OUTPUT_DIR" ]; then
    log_error "--output-dir must not be empty"
    usage
fi

scheme=Sentry
framework_name=Sentry
with_arm64e=false
# The package manifests still select the SDK implementation through SDK_V10.
export SDK_V10=1
export SENTRY_BUILD_XCFRAMEWORK=1
case "$variant" in
    Sentry-Dynamic) ;;
    Sentry-Dynamic-WithARM64e) with_arm64e=true ;;
    *) log_error "Not a shipping SDK variant: $variant"; exit 1 ;;
esac

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
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
work="$OUTPUT_DIR/build/$variant"

for sdk in "${sdks[@]}"; do
    archs="$(sdk_base_architectures "$sdk")"
    # Match the shipped Sentry-Dynamic visionOS simulator slice, which includes x86_64 even though the simulator requires Apple silicon.
    if [[ "$sdk" == xrsimulator ]]; then archs+=" x86_64"; fi
    if [[ "$with_arm64e" == true && "$sdk" != *simulator ]]; then archs+=" arm64e"; fi
    "$SCRIPT_DIR/build-static-library.sh" \
        --sdk "$sdk" \
        --scheme "$scheme" \
        --architecture-target "$framework_name" \
        --archs "$archs" \
        --package-path "$PACKAGE_PATH" \
        --configuration Release \
        --output-dir "$work"
    prepared="$work/prepared/$sdk"
    "$SCRIPT_DIR/prepare-sentry-framework-inputs.sh" \
        --swift-archive "$work/archive/$scheme/$sdk.xcarchive" \
        --output-dir "$prepared"
    # The watchOS device and simulator linkers do not support -make_mergeable.
    "$SCRIPT_DIR/build-dynamic-framework.sh" \
        --sdk "$sdk" \
        --framework-name "$framework_name" \
        --version "$version" \
        --output-dir "$work" \
        --archs "$archs" \
        --mergeable "$([[ "$sdk" == watch* ]] && echo false || echo true)" \
        --static-lib "$work/lib/$scheme/$sdk/lib$scheme-Debug.a" \
        --headers "$prepared/Headers" \
        --modules "$prepared/Modules" \
        --resources "$prepared/Resources"
done

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
"$SCRIPT_DIR/assemble-xcframework.sh" \
    --sdks "$xcframework_sdks" \
    --framework-template "$work/framework/$framework_name/SDK_NAME/$framework_name.framework" \
    --output "$OUTPUT_DIR/$variant.xcframework" \
    --require-debug-symbols
