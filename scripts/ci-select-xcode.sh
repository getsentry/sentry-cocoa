#!/bin/bash

# Selects an Xcode version and exports the latest available simulator runtime
# per platform so downstream steps (and the Makefile) don't have to pin them.
#
# Usage: ci-select-xcode.sh <version>
#   <version> may be:
#     - "latest"                   newest installed Xcode
#     - a major (e.g. "16", "26")  newest installed minor/patch in that major
#     - a major.minor (e.g. "16.4", "26.0")  newest installed patch in that line
#     - an exact installed version (e.g. "26.0.1")
#
# Exports to GITHUB_ENV (only if not already set in the caller's env):
#   XCODE_VERSION             resolved version string
#   IOS_SIMULATOR_OS          newest available iOS runtime
#   TVOS_SIMULATOR_OS         newest available tvOS runtime
#   WATCHOS_SIMULATOR_OS      newest available watchOS runtime
#   VISIONOS_SIMULATOR_OS     newest available visionOS runtime
#
# For available Xcode versions on GH-hosted runners see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

if [[ $# -lt 1 || -z "${1:-}" ]]; then
    log_error "Usage: $0 <version>  (e.g. 'latest', '16', '26', '16.4', '26.0.1')"
    exit 1
fi

XCODE_INPUT="$1"

# `xcodes installed` prints one Xcode per line; the first whitespace-separated
# token is the version (the `(Selected)` marker, build number, and path follow).
# Filter beta / RC / GM builds so CI never silently selects a prerelease Xcode
# (e.g. `Xcode_26.5_beta_2.app`) when resolving 'latest' or a major.
INSTALLED=$(xcodes installed \
    | grep -viE '(beta|release[ _-]?candidate|[^a-z](rc|gm)[^a-z])' \
    | awk '{print $1}' \
    | sort -V)

if [[ -z "$INSTALLED" ]]; then
    log_error "'xcodes installed' returned no Xcode versions."
    exit 1
fi

# Resolve the input to a concrete installed version.
case "$XCODE_INPUT" in
    latest)
        RESOLVED=$(echo "$INSTALLED" | tail -n1)
        ;;
    *)
        if echo "$INSTALLED" | grep -qx -- "$XCODE_INPUT"; then
            RESOLVED="$XCODE_INPUT"
        else
            ESCAPED="${XCODE_INPUT//./\\.}"
            RESOLVED=$(echo "$INSTALLED" | grep -E "^${ESCAPED}(\.|$)" | tail -n1 || true)
        fi
        ;;
esac

if [[ -z "${RESOLVED:-}" ]]; then
    log_error "No installed Xcode matches '$XCODE_INPUT'. Installed:"
    echo "$INSTALLED" >&2
    exit 1
fi

log_notice "Resolved Xcode '$XCODE_INPUT' -> $RESOLVED"

# We prefer this over `sudo xcode-select` because it fails fast if the version
# is not installed. `xcodes` is preinstalled on GH-hosted runners.
xcodes select "$RESOLVED"
swiftc --version

# Discover the simulator OS version that ships with the SELECTED Xcode.
# `xcrun --sdk <name> --show-sdk-version` reads from the active developer
# directory, so the value is always tied to the Xcode we just selected and is
# the right runtime version to target by default. Using `simctl list runtimes`
# would scan every runtime on the machine (including ones from other Xcodes),
# which can cause an Xcode 16 build to be pointed at an iOS 26 runtime.
sdk_version() {
    xcrun --sdk "$1" --show-sdk-version 2>/dev/null || true
}

IOS_OS=$(sdk_version iphonesimulator)
TVOS_OS=$(sdk_version appletvsimulator)
WATCHOS_OS=$(sdk_version watchsimulator)
VISIONOS_OS=$(sdk_version xrsimulator)

# Pick a sensible default iPhone for the iOS runtime that ships with this Xcode:
# the highest-numbered "iPhone N Pro" available (excluding "Pro Max"/"Pro Plus").
# This is just a default — matrix entries that pin a specific iOS major can still
# override IOS_DEVICE_NAME explicitly.
ios_default_device() {
    local os_version="$1"
    [[ -z "$os_version" ]] && return 0
    xcrun simctl list devices available 2>/dev/null \
        | awk -v platform="iOS" -v version="$os_version" '
            $0 ~ "^-- " platform " " version " --" { in_section = 1; next }
            in_section { if (/^-- /) exit; print }' \
        | grep -E "iPhone [0-9]+ Pro \(" \
        | sed -E 's/^[[:space:]]*(iPhone [0-9]+ Pro)[[:space:]]+\(.*$/\1/' \
        | sort -V \
        | tail -n1
}

IOS_DEVICE=$(ios_default_device "$IOS_OS")

log_notice "SDK versions for Xcode $RESOLVED -- iOS: ${IOS_OS:-none} (${IOS_DEVICE:-no Pro device}), tvOS: ${TVOS_OS:-none}, watchOS: ${WATCHOS_OS:-none}, visionOS: ${VISIONOS_OS:-none}"

# Always emit step outputs (kebab-case keys) so callers using the composite
# action can read them as `${{ steps.<id>.outputs.<name> }}`.
emit_output() {
    local name="$1" value="$2"
    [[ -z "$value" ]] && return 0
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "$name=$value" >> "$GITHUB_OUTPUT"
    fi
}

emit_output xcode-version         "$RESOLVED"
emit_output ios-simulator-os      "$IOS_OS"
emit_output ios-device-name       "$IOS_DEVICE"
emit_output tvos-simulator-os     "$TVOS_OS"
emit_output watchos-simulator-os  "$WATCHOS_OS"
emit_output visionos-simulator-os "$VISIONOS_OS"

# Export to GITHUB_ENV. Skip any var that's already set so a caller's env: block
# (job- or step-level) can pin a specific OS without being clobbered here.
emit_env_if_unset() {
    local name="$1" value="$2"
    [[ -z "$value" ]] && return 0
    if [[ -n "${!name:-}" ]]; then
        log_notice "Keeping existing $name=${!name} (discovered: $value)"
        return 0
    fi
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        echo "$name=$value" >> "$GITHUB_ENV"
    fi
}

if [[ -n "${GITHUB_ENV:-}" ]]; then
    # XCODE_VERSION always reflects the resolved version, so workflows that
    # use it for artifact naming get the concrete version even when the input
    # was 'latest' or a major.
    echo "XCODE_VERSION=$RESOLVED" >> "$GITHUB_ENV"
fi

emit_env_if_unset IOS_SIMULATOR_OS      "$IOS_OS"
emit_env_if_unset IOS_DEVICE_NAME       "$IOS_DEVICE"
emit_env_if_unset TVOS_SIMULATOR_OS     "$TVOS_OS"
emit_env_if_unset WATCHOS_SIMULATOR_OS  "$WATCHOS_OS"
emit_env_if_unset VISIONOS_SIMULATOR_OS "$VISIONOS_OS"

# On GH Actions this command should cause the runner to recache and detect
# missing runtimes, as pointed out in
# https://github.com/actions/runner-images/issues/12948#issuecomment-3248563014
# See https://github.com/getsentry/sentry-cocoa/pull/6053 for context.
begin_group "List Available Simulators"

start_time=$(date +%s)
xcrun simctl list
end_time=$(date +%s)
xcrun_simctl_list_duration=$((end_time - start_time))

end_group

echo "List Available Simulators completed in ${xcrun_simctl_list_duration} seconds"
