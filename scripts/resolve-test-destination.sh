#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

OS=""
DEVICE=""
PLATFORM=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Resolve the simulator test destination (OS version and device) for a given platform.

OPTIONS:
    --os <version>         Explicit simulator OS version, e.g. '17.5' (optional)
    --device <name>        Explicit device name, e.g. 'iPhone 15 Pro' (optional)
    --platform <platform>  Target platform: iOS, macOS, tvOS, watchOS, visionOS, or Catalyst (required)

EXAMPLES:
    $(basename "$0") --platform iOS
    $(basename "$0") --platform tvOS --os 18.2
    $(basename "$0") --platform iOS --os 17.5 --device "iPhone 15 Pro"

EOF
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
    log_error "--platform is required"
    usage
fi

# Strips any patch component, e.g. 26.4.1 -> 26.4.
major_minor() {
    echo "$1" | awk -F. '{print $1"."$2}'
}

# Prints the newest "iPhone N Pro" (excluding Max/Plus) in the iOS runtime
# with the given major.minor version, or nothing if there is none.
# `simctl list devices` groups devices by major.minor runtime sections.
find_newest_iphone_pro() {
    local os_mm="$1"
    xcrun simctl list devices available 2>/dev/null \
        | awk -v platform="iOS" -v version="$os_mm" '
            $0 ~ "^-- " platform " " version " --" { in_section = 1; next }
            in_section { if (/^-- /) exit; print }' \
        | grep -E "iPhone [0-9]+ Pro \(" \
        | sed -E 's/^[[:space:]]*(iPhone [0-9]+ Pro)[[:space:]]+\(.*$/\1/' \
        | sort -V \
        | tail -n1 || true
}

# Prints the exact versions of available iOS runtimes that share the given
# major version and have a lower minor version, newest first.
# E.g. for 27.2 this prints 27.1 and 27.0 if both are installed.
list_lower_minor_ios_runtimes() {
    local major="$1"
    local minor="$2"
    xcrun simctl list runtimes -j 2>/dev/null \
        | jq -r --argjson major "$major" --argjson minor "$minor" '
            .runtimes[]
            | select(.isAvailable == true and .platform == "iOS")
            | .version
            | (split(".") | map(tonumber)) as $parts
            | select($parts[0] == $major and ($parts[1] // 0) < $minor)' \
        | sort -ruV || true
}

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
            # Pick the newest "iPhone N Pro" available in the resolved iOS runtime.
            OS_MM=$(major_minor "$TEST_OS")
            TEST_DEVICE=$(find_newest_iphone_pro "$OS_MM")

            # Runner images can ship a new minor runtime (e.g. iOS 27.1) without
            # pre-created iPhone Pro simulators. Walk down the minor versions of
            # the same major (27.1 -> 27.0) and use the first runtime that has
            # one. TEST_OS is updated to the exact fallback runtime version so
            # the runtime-loaded check, simulator boot, and xcodebuild
            # destination all agree.
            if [ -z "$TEST_DEVICE" ] && [ "$PLATFORM" = "iOS" ] \
                && [[ "$OS_MM" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
                OS_MAJOR="${BASH_REMATCH[1]}"
                OS_MINOR="${BASH_REMATCH[2]}"
                while IFS= read -r FALLBACK_OS; do
                    [ -n "$FALLBACK_OS" ] || continue
                    TEST_DEVICE=$(find_newest_iphone_pro "$(major_minor "$FALLBACK_OS")")
                    if [ -n "$TEST_DEVICE" ]; then
                        log_warning "No iPhone Pro simulator for iOS $TEST_OS, falling back to $TEST_DEVICE on iOS $FALLBACK_OS"
                        TEST_OS="$FALLBACK_OS"
                        break
                    fi
                done < <(list_lower_minor_ios_runtimes "$OS_MAJOR" "$OS_MINOR")
            fi

            if [ -z "$TEST_DEVICE" ] && [ "$PLATFORM" = "iOS" ]; then
                log_warning "No iPhone Pro simulator found for iOS $TEST_OS or a lower minor version of the same major"
            fi
            ;;
        tvOS)
            TEST_DEVICE="Apple TV"
            ;;
        watchOS)
            # WatchKit schemes fail to match iPhone-paired watches by
            # platform=watchOS Simulator,name=... (xcodebuild reports them as
            # DVTiPhoneSimulator). Prefer unpaired watches from simctl pairs;
            # fall back to the newest watch in the runtime if every watch is paired.
            #
            # OS=latest (the no --os default) is not a simctl runtime id, so
            # resolve it to the newest watchOS runtime that has devices.
            OS_MM=$(echo "$TEST_OS" | awk -F. '{print $1"."$2}')
            devices_json=$(xcrun simctl list devices available -j 2>/dev/null || echo '{"devices":{}}')
            if [[ ! "$OS_MM" =~ ^[0-9]+\.[0-9]+$ ]]; then
                OS_MM=$(printf '%s\n' "$devices_json" \
                    | jq -r '.devices | keys[] | select(test("watchOS-[0-9]+-[0-9]+")) | capture("watchOS-(?<v>[0-9]+-[0-9]+)") | .v' \
                    | tr '-' '.' \
                    | sort -V | tail -n1 || true)
            fi
            OS_KEY=$(echo "$OS_MM" | tr '.' '-')
            paired_json=$(xcrun simctl list pairs -j 2>/dev/null \
                | jq -c '[.pairs[].watch.udid] // []' 2>/dev/null \
                || echo '[]')
            TEST_DEVICE=$(printf '%s\n' "$devices_json" \
                | jq -r --arg key "$OS_KEY" --argjson paired "$paired_json" '
                    [
                      .devices
                      | to_entries[]
                      | select(.key | endswith("watchOS-" + $key))
                      | .value[]
                      | select(.isAvailable != false)
                      | {name, unpaired: ((.udid as $id | ($paired | index($id)) == null))}
                    ] as $watches
                    | ($watches | map(select(.unpaired)) | if length > 0 then . else $watches end)
                    | .[].name
                ' 2>/dev/null | sort -V | tail -n1 || true)
            ;;
        visionOS)
            TEST_DEVICE="Apple Vision Pro"
            ;;
        *)
            TEST_DEVICE=""
            ;;
    esac
fi

set_output "TEST_OS" "$TEST_OS"
set_env "TEST_OS" "$TEST_OS"

set_output "TEST_DEVICE" "$TEST_DEVICE"
set_env "TEST_DEVICE" "$TEST_DEVICE"

log_info "Resolved: platform=$PLATFORM os=$TEST_OS device=$TEST_DEVICE"
