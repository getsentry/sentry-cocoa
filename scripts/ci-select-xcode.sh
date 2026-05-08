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

log_info "Resolved Xcode '$XCODE_INPUT' -> $RESOLVED"

# We prefer this over `sudo xcode-select` because it fails fast if the version
# is not installed. `xcodes` is preinstalled on GH-hosted runners.
xcodes select "$RESOLVED"
# Diagnostic only. A freshly-selected Xcode that hasn't been "first-launched"
# may make the first `swiftc` invocation slow and/or non-zero; don't let that
# abort the rest of the script (env/outputs export still needs to happen).
log_info "Running swiftc --version (may take a while on first launch of a fresh Xcode)..."
swiftc --version || log_warning "swiftc --version exited non-zero (continuing — diagnostic only)"
log_info "swiftc --version returned"

# Discover the simulator OS version that ships with the SELECTED Xcode.
# `xcrun --sdk <name> --show-sdk-version` reads from the active developer
# directory, so the value is always tied to the Xcode we just selected.
# Using `simctl list runtimes` alone would scan every runtime on the machine
# (including ones from other Xcodes), which would point an Xcode 16 build at
# an iOS 26 runtime.
#
# The SDK version isn't always usable as-is for `-destination OS=...` though:
# Apple sometimes ships a runtime patch update beyond the SDK's advertised
# version (e.g. SDK 26.4 with runtime 26.4.1). To target a runtime that
# actually exists, we anchor on the SDK's major.minor and pick the newest
# installed runtime in that line. If no matching runtime is installed, we
# fall back to the SDK version so callers still get a useful default.
log_info "Querying simctl runtimes JSON..."
RUNTIMES_JSON=$(xcrun simctl list runtimes -j 2>/dev/null || echo '{"runtimes":[]}')
RUNTIMES_COUNT=$(echo "$RUNTIMES_JSON" | jq -r '.runtimes | length' 2>/dev/null || echo "?")
log_info "simctl returned $RUNTIMES_COUNT runtimes"

# Print a compact platform/version table once for visibility into what we're
# matching against. Helps diagnose "expected 26.4.1 but got 26.4" issues.
begin_group "Available simulator runtimes"
echo "$RUNTIMES_JSON" \
    | jq -r '.runtimes[] | "\(.platform)\t\(.version // "<null>")\tavailable=\(.isAvailable // false)"' 2>/dev/null \
    | sort \
    || log_warning "could not pretty-print runtimes (jq error)"
end_group

resolve_simulator_os() {
    local sdk="$1"
    local platform_a="$2"
    local platform_b="${3:-$2}"
    # CRITICAL: this function's stdout is captured by `$(resolve_simulator_os)`
    # at the call site. Anything we want to log MUST go to stderr (`>&2`),
    # otherwise it pollutes the captured value and ends up appended to
    # $GITHUB_ENV / $GITHUB_OUTPUT, which GH Actions then refuses to parse.
    log_info "resolve_simulator_os(sdk=$sdk platforms=[$platform_a,$platform_b])" >&2

    local sdk_v
    sdk_v=$(xcrun --sdk "$sdk" --show-sdk-version 2>/dev/null || true)
    log_info "  $sdk SDK version: ${sdk_v:-<empty>}" >&2
    if [[ -z "$sdk_v" ]]; then
        log_info "  (no SDK version — skipping platform)" >&2
        return 0
    fi

    local mm
    mm=$(echo "$sdk_v" | awk -F. '{print $1"."$2}')
    log_info "  major.minor cap: $mm" >&2

    # Defensive: simctl can list partially-loaded runtimes with `.version == null`,
    # which would crash jq's `startswith()`. The `select(.version != null)` skips
    # those, and the `|| matched=""` keeps an unexpected jq error from killing
    # the whole script (we just fall back to the SDK version below).
    local matched=""
    matched=$(echo "$RUNTIMES_JSON" | jq -r \
        --arg pa "$platform_a" \
        --arg pb "$platform_b" \
        --arg mm "$mm" \
        '[.runtimes[]
          | select(.isAvailable == true)
          | select(.platform == $pa or .platform == $pb)
          | select(.version != null)
          | select(.version == $mm or (.version | startswith($mm + ".")))
          | .version]
         | sort_by(split(".") | map(tonumber))
         | last // empty' 2>/dev/null) || matched=""
    log_info "  matched runtime: ${matched:-<none>}" >&2

    local result="${matched:-$sdk_v}"
    log_info "  -> resolved: $result" >&2
    echo "$result"
}

log_info "Resolving simulator OS for each platform..."
IOS_OS=$(resolve_simulator_os iphonesimulator iOS)
TVOS_OS=$(resolve_simulator_os appletvsimulator tvOS)
WATCHOS_OS=$(resolve_simulator_os watchsimulator watchOS)
VISIONOS_OS=$(resolve_simulator_os xrsimulator visionOS xrOS)
log_info "Per-platform resolution complete"

log_info "SDK versions for Xcode $RESOLVED -- iOS: ${IOS_OS:-none}, tvOS: ${TVOS_OS:-none}, watchOS: ${WATCHOS_OS:-none}, visionOS: ${VISIONOS_OS:-none}"

log_info "Emitting step outputs..."
set_output xcode-version         "$RESOLVED"
set_output ios-simulator-os      "$IOS_OS"
set_output tvos-simulator-os     "$TVOS_OS"
set_output watchos-simulator-os  "$WATCHOS_OS"
set_output visionos-simulator-os "$VISIONOS_OS"

# Export to GITHUB_ENV. Skip any var that's already set so a caller's env: block
# (job- or step-level) can pin a specific OS without being clobbered here.
emit_env_if_unset() {
    local name="$1" value="$2"
    [[ -z "$value" ]] && return 0
    if [[ -n "${!name:-}" ]]; then
        log_info "Keeping existing $name=${!name} (discovered: $value)"
        return 0
    fi
    set_env "$name" "$value"
}

log_info "Emitting GITHUB_ENV exports..."
set_env "XCODE_VERSION" "$RESOLVED"

emit_env_if_unset IOS_SIMULATOR_OS      "$IOS_OS"
emit_env_if_unset TVOS_SIMULATOR_OS     "$TVOS_OS"
emit_env_if_unset WATCHOS_SIMULATOR_OS  "$WATCHOS_OS"
emit_env_if_unset VISIONOS_SIMULATOR_OS "$VISIONOS_OS"
log_info "Exports complete"

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

log_info "List Available Simulators completed in ${xcrun_simctl_list_duration} seconds"
