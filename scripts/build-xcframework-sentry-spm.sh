#!/bin/bash
# Build SwiftPM SDK slices and assemble a self-contained dynamic or static XCFramework.
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
generation=v9
variant=Sentry-Dynamic
if [ "${SDK_V10:-0}" = 1 ]; then
    generation=v10
    variant=SentryV10-Dynamic
fi
OUTPUT_DIR="$PACKAGE_PATH/XCFrameworkBuildPath/SPM/$generation"

usage() {
    log_info "Usage: $0 [options]"
    log_info "  -v, --variant <name>     Shipping artifact basename (default: dynamic for the selected generation)"
    log_info "  -d, --sdks <list>        Comma-separated SDKs or AllSDKs, iOSOnly, macOSOnly, macCatalystOnly (default: all)"
    log_info "  -o, --output-dir <path>  Build directory (default: <repo>/XCFrameworkBuildPath/SPM/v9 or v10)"
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
linkage=dynamic
with_arm64e=false
# Select the source module name without changing the SDK generation.
export SENTRY_BUILD_XCFRAMEWORK=1
case "$generation/$variant" in
    v9/Sentry|v10/SentryV10) linkage=static; with_arm64e=true ;;
    v9/Sentry-Dynamic) ;;
    v10/SentryV10-Dynamic|v9/Sentry-Dynamic-WithARM64e) with_arm64e=true ;;
    *) log_error "Not a shipping $generation SDK variant: $variant"; exit 1 ;;
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
        --product-type "$linkage" \
        --swift-archive "$work/archive/$scheme/$sdk.xcarchive" \
        --output-dir "$prepared"
    lib="$work/lib/$scheme/$sdk/lib$scheme-Debug.a"
    mergeable=false
    if [[ "$linkage" == static ]]; then
        lib="$work/lib/$scheme/$sdk/lib$scheme.a"
    elif [[ "$sdk" != watch* ]]; then
        # The watchOS device and simulator linkers do not support -make_mergeable.
        mergeable=true
    fi
    "$SCRIPT_DIR/package-framework-slice.sh" \
        --sdk "$sdk" \
        --framework-name "$framework_name" \
        --version "$version" \
        --output-dir "$work" \
        --product-type "$linkage" \
        --archs "$archs" \
        --mergeable "$mergeable" \
        --static-lib "$lib" \
        --headers "$prepared/Headers" \
        --modules "$prepared/Modules" \
        --resources "$prepared/Resources"
done

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
assembly_args=()
if [[ "$linkage" == dynamic ]]; then assembly_args+=(--require-debug-symbols); fi
"$SCRIPT_DIR/assemble-xcframework.sh" \
    --sdks "$xcframework_sdks" \
    --framework-template "$work/framework/$framework_name/SDK_NAME/$framework_name.framework" \
    --output "$OUTPUT_DIR/$variant.xcframework" \
    "${assembly_args[@]+"${assembly_args[@]}"}"
