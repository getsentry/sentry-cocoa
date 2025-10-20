#!/bin/bash

# We boot the simulator because the GitHub Actions runner sometimes fails to launch the simulator.
# We do this manually to know immediately if the simulator is not booting.
# Because otherwise we compile the tests first and then try to boot the simulator.

# For available Xcode and simulator versions see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

# Parse named arguments
XCODE_VERSION="16.2" # Default value

while [[ $# -gt 0 ]]; do
    case $1 in
        -x|--xcode)
            XCODE_VERSION="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            log_error "Usage: $0 [-x|--xcode <version>]"
            exit 1
            ;;
    esac
done

log_notice "Starting simulator boot process with Xcode version: $XCODE_VERSION"

begin_group "Simulator Selection"
SIMULATOR="iPhone 16 Pro"
IOS_VERSION="18.4"

# Select simulator based on Xcode version
case "$XCODE_VERSION" in
    "14.3.1")
        SIMULATOR="iPhone 14 Pro"
        IOS_VERSION="16.4"
        log_notice "Selected: $SIMULATOR with iOS $IOS_VERSION for Xcode $XCODE_VERSION"
        ;;
    "15.4")
        SIMULATOR="iPhone 15 Pro"
        IOS_VERSION="17.5"
        log_notice "Selected: $SIMULATOR with iOS $IOS_VERSION for Xcode $XCODE_VERSION"
        ;;
    "16.2")
        SIMULATOR="iPhone 16 Pro"
        IOS_VERSION="18.4"
        log_notice "Selected: $SIMULATOR with iOS $IOS_VERSION for Xcode $XCODE_VERSION"
        ;;
    "26.0.1")
        SIMULATOR="iPhone 17 Pro"
        IOS_VERSION="26.0"
        log_notice "Selected: $SIMULATOR with iOS $IOS_VERSION for Xcode $XCODE_VERSION"
        ;;
    *)
        SIMULATOR="iPhone 16 Pro" # Default fallback
        IOS_VERSION="18.4"
        log_warning "Unknown Xcode version '$XCODE_VERSION', using default: $SIMULATOR with iOS $IOS_VERSION"
        ;;
esac
end_group

begin_group "Available Devices"
log_notice "Listing all available simulators:"
xcrun simctl list devices available
end_group

begin_group "Device Discovery"
log_notice "Searching for simulator: $SIMULATOR running iOS $IOS_VERSION"

UDID=$(xcrun simctl list devices available | \
grep -A 5 "^-- iOS $IOS_VERSION --" | \
grep "$SIMULATOR (" | \
sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p' | \
head -n1)

if [ -z "$UDID" ]; then
    log_error "Failed to find UDID for simulator: $SIMULATOR with iOS $IOS_VERSION"
    log_error "Available devices:"
    xcrun simctl list devices available
    exit 1
fi

log_notice "Found simulator UDID: $UDID"
end_group

begin_group "Simulator Boot"
log_notice "Booting simulator: $SIMULATOR - iOS $IOS_VERSION (UDID: $UDID)"

if ! xcrun simctl boot "$UDID" 2>/dev/null; then
    # If boot fails, it might be because the simulator is already booted
    CURRENT_STATE=$(xcrun simctl list devices | grep "$UDID" | sed 's/.*(\([^)]*\)).*$/\1/')
    if [ "$CURRENT_STATE" = "Booted" ]; then
        log_notice "Simulator is already booted"
    else
        log_error "Failed to boot simulator. Current state: $CURRENT_STATE"
        exit 1
    fi
else
    log_notice "Simulator boot command executed successfully"
fi

log_notice "Opening Simulator app UI"
# We use `open -a Simulator` because there's no lower-level CLI like `simctl` to display the simulator UI available.
if ! open -a Simulator; then
    log_error "Failed to open Simulator app"
    exit 1
fi
log_notice "Simulator app opened successfully"
end_group

begin_group "Boot Status Verification"
log_notice "Waiting for simulator to fully boot (this may take a moment)"
# We need to wait for the simulator to boot to avoid the test to fail due to timeout (because the simulator is not booted yet)
if ! xcrun simctl bootstatus "$UDID"; then
    log_error "Failed to verify simulator boot status"
    exit 1
fi
log_notice "Simulator boot process completed successfully"
end_group

begin_group "Booted Device Details"
log_notice "Listing all currently booted simulators:"
if ! xcrun simctl list devices --json | jq '.devices | to_entries[] | select(.value[] | .state == "Booted")'; then
    log_warning "Failed to retrieve booted device details (jq might not be available)"
    log_notice "Fallback: listing devices without JSON formatting"
    xcrun simctl list devices | grep "Booted"
fi
end_group

log_notice "Simulator boot process completed successfully!"
