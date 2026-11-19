#!/bin/bash
#
# Builds all slices for a V10 XCFramework variant and assembles the final
# xcframework.
#
# Orchestrates per-SDK slice builds (sequentially) then assembles the final
# xcframework. For CI, each slice runs as a separate parallel job; this script
# is the local equivalent that runs them in sequence.
#
# The shared slice builder propagates release architectures to KSCrash package
# targets in both development configurations, including arm64e device slices.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SUFFIX=""
MACH_O_TYPE="inherit"
SDKS=""

# The V10 target uses PRODUCT_NAME = Sentry (via xcconfig), so the framework
# on disk is always named Sentry.framework regardless of the scheme.
SCHEME="SentryV10"
PRODUCT_NAME="Sentry"

# V10 slices use the ReleaseV10 configuration.
CONFIGURATION_SUFFIX="V10"

usage() {
    log_info "Usage: $0 [options]"
    log_info "  --suffix <suffix>      Output xcframework name suffix (default: empty)"
    log_info "  --mach-o-type <type>   staticlib for a static build; omit for dynamic (default: inherit from xcconfig)"
    log_info "  --sdks <list>          Comma-separated SDKs or AllSDKs (default: all)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --suffix)       SUFFIX="$2";      shift 2 ;;
        --mach-o-type)  MACH_O_TYPE="$2"; shift 2 ;;
        --sdks)         SDKS="$2";        shift 2 ;;
        -h|--help)      usage ;;
        *)              log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$SDKS" ] || [ "$SDKS" = "AllSDKs" ]; then
    sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
else
    IFS=',' read -r -a sdks <<< "$SDKS"
fi

for sdk in "${sdks[@]}"; do
    "$SCRIPT_DIR/build-xcframework-slice.sh" --sdk "$sdk" --scheme "$SCHEME" --suffix "$SUFFIX" \
        --mach-o-type "$MACH_O_TYPE" --configuration-suffix "$CONFIGURATION_SUFFIX" \
        --product-name "$PRODUCT_NAME"
done

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
"$SCRIPT_DIR/assemble-xcframework.sh" --scheme "$SCHEME" --suffix "$SUFFIX" \
    --sdks "$xcframework_sdks" \
    --archive-template "$(pwd)/XCFrameworkBuildPath/archive/$SCHEME$SUFFIX/SDK_NAME.xcarchive" \
    --product-name "$PRODUCT_NAME"
