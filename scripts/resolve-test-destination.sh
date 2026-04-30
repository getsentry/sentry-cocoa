#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

OS=""
DEVICE=""
PLATFORM=""

usage() {
    log_notice "Usage: $0"
    log_notice "  --os <version>         Explicit simulator OS version, e.g. '17.5' (optional)"
    log_notice "  --device <name>        Explicit device name, e.g. 'iPhone 15 Pro' (optional)"
    log_notice "  --platform <platform>  Target platform: iOS, macOS, tvOS, watchOS, visionOS, or Catalyst (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --os)        OS="$2";        shift 2 ;;
        --device)    DEVICE="$2";    shift 2 ;;
        --platform)  PLATFORM="$2";  shift 2 ;;
        *)           usage ;;
    esac
done

if [ -z "$PLATFORM" ]; then
    log_error "Error: --platform is required"
    usage
fi

if [ -n "$OS" ]; then
    TEST_OS="$OS"
else
    case "$PLATFORM" in
        iOS|Catalyst) TEST_OS="${IOS_SIMULATOR_OS:-latest}" ;;
        tvOS)         TEST_OS="${TVOS_SIMULATOR_OS:-latest}" ;;
        watchOS)      TEST_OS="${WATCHOS_SIMULATOR_OS:-latest}" ;;
        visionOS)     TEST_OS="${VISIONOS_SIMULATOR_OS:-latest}" ;;
        macOS)        TEST_OS="latest" ;;
        *)            TEST_OS="latest" ;;
    esac
fi

if [ -n "$DEVICE" ]; then
    TEST_DEVICE="$DEVICE"
else
    case "$PLATFORM" in
        iOS|Catalyst)
            # Pick the newest "iPhone N Pro" (excluding Max/Plus) available in
            # the resolved iOS runtime. `simctl list devices` groups by major.minor
            # so strip any patch component before searching.
            OS_MM=$(echo "$TEST_OS" | awk -F. '{print $1"."$2}')
            TEST_DEVICE=$(xcrun simctl list devices available 2>/dev/null \
                | awk -v platform="iOS" -v version="$OS_MM" '
                    $0 ~ "^-- " platform " " version " --" { in_section = 1; next }
                    in_section { if (/^-- /) exit; print }' \
                | grep -E "iPhone [0-9]+ Pro \(" \
                | sed -E 's/^[[:space:]]*(iPhone [0-9]+ Pro)[[:space:]]+\(.*$/\1/' \
                | sort -V \
                | tail -n1) || TEST_DEVICE=""
            ;;
        tvOS)
            TEST_DEVICE="Apple TV"
            ;;
        watchOS)
            # Pick the newest Apple Watch available in the resolved watchOS runtime.
            # Watch names include parenthetical sizes (e.g. "Apple Watch Ultra 3 (49mm)")
            # so we strip from the UUID pattern `(XXXX-...) (State)` rather than the
            # first `(`, which would lose the size.
            OS_MM=$(echo "$TEST_OS" | awk -F. '{print $1"."$2}')
            TEST_DEVICE=$(xcrun simctl list devices available 2>/dev/null \
                | awk -v platform="watchOS" -v version="$OS_MM" '
                    $0 ~ "^-- " platform " " version " --" { in_section = 1; next }
                    in_section { if (/^-- /) exit; print }' \
                | grep -E "Apple Watch" \
                | sed -E 's/^[[:space:]]+//; s/ \([A-F0-9-]+\) \([A-Za-z]+\)[[:space:]]*$//' \
                | sort -V \
                | tail -n1) || TEST_DEVICE=""
            ;;
        visionOS)
            TEST_DEVICE="Apple Vision Pro"
            ;;
        *)
            TEST_DEVICE=""
            ;;
    esac
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "TEST_OS=$TEST_OS" >> "$GITHUB_OUTPUT"
    echo "TEST_DEVICE=$TEST_DEVICE" >> "$GITHUB_OUTPUT"
fi

if [ -n "${GITHUB_ENV:-}" ]; then
    echo "TEST_OS=$TEST_OS" >> "$GITHUB_ENV"
    echo "TEST_DEVICE=$TEST_DEVICE" >> "$GITHUB_ENV"
fi

log_notice "Resolved: platform=$PLATFORM os=$TEST_OS device=$TEST_DEVICE"
