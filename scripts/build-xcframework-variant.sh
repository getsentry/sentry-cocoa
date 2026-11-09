#!/bin/bash
#
# Builds all slices for an XCFramework variant, removes excluded architectures,
# and assembles the final xcframework.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SCHEME=""
SUFFIX=""
MACH_O_TYPE="mh_dylib"
CONFIGURATION_SUFFIX=""
SDKS=""
EXCLUDED_ARCHS=""

usage() {
    log_info "Usage: $0 --scheme <name> [options]"
    log_info "  --scheme <name>              Xcode scheme (required)"
    log_info "  --suffix <suffix>            Output suffix (e.g. -Dynamic)"
    log_info "  --mach-o-type <type>         mh_dylib or staticlib (default: mh_dylib)"
    log_info "  --configuration-suffix <s>   Configuration suffix (e.g. WithoutUIKit)"
    log_info "  --sdks <list>                Comma-separated SDKs or AllSDKs (default: all)"
    log_info "  --excluded-archs <archs>     Architectures to strip (e.g. arm64e)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme)               SCHEME="$2";               shift 2 ;;
        --suffix)               SUFFIX="$2";               shift 2 ;;
        --mach-o-type)          MACH_O_TYPE="$2";          shift 2 ;;
        --configuration-suffix) CONFIGURATION_SUFFIX="$2"; shift 2 ;;
        --sdks)                 SDKS="$2";                 shift 2 ;;
        --excluded-archs)       EXCLUDED_ARCHS="$2";       shift 2 ;;
        -h|--help)              usage ;;
        *)                      log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$SCHEME" ]; then
    log_error "Error: --scheme is required"
    usage
fi

if [ "$SDKS" = "iOSOnly" ]; then
    sdks=( iphoneos iphonesimulator )
elif [ "$SDKS" = "macOSOnly" ]; then
    sdks=( macosx )
elif [ "$SDKS" = "macCatalystOnly" ]; then
    sdks=( maccatalyst )
elif [ -z "$SDKS" ] || [ "$SDKS" = "AllSDKs" ]; then
    sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
else
    IFS=',' read -r -a sdks <<< "$SDKS"
fi

for sdk in "${sdks[@]}"; do
    "$SCRIPT_DIR/build-xcframework-slice.sh" --sdk "$sdk" --scheme "$SCHEME" \
        --suffix "$SUFFIX" --mach-o-type "$MACH_O_TYPE" --configuration-suffix "$CONFIGURATION_SUFFIX"
done

if [ -n "$EXCLUDED_ARCHS" ]; then
    "$SCRIPT_DIR/remove-architectures.sh" --xcarchive "$(pwd)/XCFrameworkBuildPath/archive/$SCHEME$SUFFIX/" --excluded-arch "$EXCLUDED_ARCHS"
fi

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
"$SCRIPT_DIR/assemble-xcframework.sh" --scheme "$SCHEME" --suffix "$SUFFIX" \
    --configuration-suffix "$CONFIGURATION_SUFFIX" --sdks "$xcframework_sdks" \
    --archive-template "$(pwd)/XCFrameworkBuildPath/archive/$SCHEME$SUFFIX/SDK_NAME.xcarchive"
