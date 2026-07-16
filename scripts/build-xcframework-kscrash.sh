#!/bin/bash
#
# Builds all slices for a Sentry+KSCrash XCFramework variant and assembles
# the final xcframework.
#
# Orchestrates per-SDK slice builds (sequentially) then assembles the final
# xcframework. For CI, each slice runs as a separate parallel job; this script
# is the local equivalent that runs them in sequence.
#
# The Sentry+KSCrash xcconfig disables arm64e on tvOS, watchOS, and Mac
# Catalyst to work around an Xcode UI bug where the IDE does not propagate
# ARCHS into SPM package builds.
#
# However, even for the SDKs where xcconfig already includes arm64e (iOS,
# macOS, visionOS), xcconfig ARCHS settings also do NOT propagate to SPM
# sub-targets — only command-line build setting overrides do. Without the
# override, SPM packages (KSCrash) build arm64 only, producing a
# symbol-inconsistent fat binary that fails validation.
#
# Therefore this script passes ARCHS explicitly on the command line for every
# arm64e-capable device SDK, ensuring SPM sub-targets also build arm64e.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SUFFIX=""
MACH_O_TYPE="inherit"
SDKS=""

# The Sentry+KSCrash target uses PRODUCT_NAME = Sentry (via xcconfig), so the
# framework on disk is always named Sentry.framework regardless of the scheme.
SCHEME="Sentry+KSCrash"
PRODUCT_NAME="Sentry"

# KSCrash builds use the ReleaseV10 configuration.
CONFIGURATION_SUFFIX="V10"

# All device SDKs that include arm64e in the xcframework slice. ARCHS must be
# passed on the command line (not via xcconfig) so that SPM sub-targets inherit
# the arch list and produce symbol-consistent fat binaries.
ARM64E_DEVICE_SDKS=( iphoneos macosx maccatalyst appletvos watchos xros )

usage() {
    log_notice "Usage: $0 [options]"
    log_notice "  --suffix <suffix>      Output xcframework name suffix (default: empty)"
    log_notice "  --mach-o-type <type>   staticlib for a static build; omit for dynamic (default: inherit from xcconfig)"
    log_notice "  --sdks <list>          Comma-separated SDKs or AllSDKs (default: all)"
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
    extra_build_settings=()

    for arm64e_sdk in "${ARM64E_DEVICE_SDKS[@]}"; do
        if [[ "$sdk" == "$arm64e_sdk" ]]; then
            # Pass ARCHS on the command line so it propagates to SPM sub-targets
            # (KSCrash packages), ensuring arm64e symbols are present in all
            # architectures of the fat binary.
            extra_build_settings+=( "ARCHS=\$(ARCHS_STANDARD) arm64e" )
            break
        fi
    done

    "$SCRIPT_DIR/build-xcframework-slice.sh" \
        "$sdk" \
        "$SCHEME" \
        "$SUFFIX" \
        "$MACH_O_TYPE" \
        "$CONFIGURATION_SUFFIX" \
        "$PRODUCT_NAME" \
        "${extra_build_settings[@]+"${extra_build_settings[@]}"}"
done

xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
"$SCRIPT_DIR/assemble-xcframework.sh" \
    "$SCHEME" \
    "$SUFFIX" \
    "" \
    "$xcframework_sdks" \
    "$(pwd)/XCFrameworkBuildPath/archive/$SCHEME$SUFFIX/SDK_NAME.xcarchive" \
    "$PRODUCT_NAME"
