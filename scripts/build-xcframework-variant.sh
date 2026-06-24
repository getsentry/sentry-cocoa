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
    log_notice "Usage: $0 --scheme <name> [options]"
    log_notice "  --scheme <name>              Xcode scheme (required)"
    log_notice "  --suffix <suffix>            Output suffix (e.g. -Dynamic)"
    log_notice "  --mach-o-type <type>         mh_dylib or staticlib (default: mh_dylib)"
    log_notice "  --configuration-suffix <s>   Configuration suffix (e.g. WithoutUIKit)"
    log_notice "  --sdks <list>                Comma-separated SDKs or AllSDKs (default: all)"
    log_notice "  --excluded-archs <archs>     Architectures to strip (e.g. arm64e)"
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
    ./scripts/build-xcframework-slice.sh "$sdk" "$SCHEME" "$SUFFIX" "$MACH_O_TYPE" "$CONFIGURATION_SUFFIX"
done

if [ -n "$EXCLUDED_ARCHS" ]; then
    ./scripts/remove-architectures.sh "$(pwd)/XCFrameworkBuildPath/archive/$SCHEME$SUFFIX/" "$EXCLUDED_ARCHS"
fi

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "$SCHEME" "$SUFFIX" "$CONFIGURATION_SUFFIX" "$xcframework_sdks" "$(pwd)/XCFrameworkBuildPath/archive/$SCHEME$SUFFIX/SDK_NAME.xcarchive"
