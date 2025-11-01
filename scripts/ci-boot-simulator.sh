#!/bin/bash

# We boot the simulator because the GitHub Actions runner sometimes fails to launch the simulator.
# We do this manually to know immediately if the simulator is not booting.
# Because otherwise we compile the tests first and then try to boot the simulator.

# For available Xcode and simulator versions see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md

set -euo pipefail

# Timeout function that works on macOS without external dependencies
run_with_timeout() {
    local timeout=$1
    shift
    
    # Run command in background
    "$@" &
    local pid=$!
    
    # Wait for command with timeout
    local count=0
    while kill -0 $pid 2>/dev/null; do
        if [ $count -ge "$timeout" ]; then
            kill -TERM $pid 2>/dev/null || true
            sleep 1
            kill -KILL $pid 2>/dev/null || true
            return 124  # Same exit code as GNU timeout
        fi
        sleep 1
        ((count++))
    done
    
    # Get the exit code of the command
    wait $pid
    return $?
}

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

# Parse named arguments
XCODE_VERSION="16.2" # Default value
DEVICE_NAME=""
OS_VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -x|--xcode)
            XCODE_VERSION="$2"
            shift 2
            ;;
        -d|--device)
            DEVICE_NAME="$2"
            shift 2
            ;;
        -o|--os-version)
            OS_VERSION="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            log_error "Usage: $0 [-x|--xcode <version>] [-d|--device <device_name>] [-o|--os-version <os_version>]"
            exit 1
            ;;
    esac
done

log_notice "Starting simulator boot process with Xcode version: $XCODE_VERSION"

begin_group "Simulator Selection"

# If device and OS version are provided, use them directly
if [ -n "$DEVICE_NAME" ] && [ -n "$OS_VERSION" ]; then
    SIMULATOR="$DEVICE_NAME"
    IOS_VERSION="$OS_VERSION"
    log_notice "Using provided parameters: $SIMULATOR with iOS $IOS_VERSION"
else
    # Fallback to Xcode version-based selection for backward compatibility
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
        "26.1")
            SIMULATOR="iPhone 17 Pro"
            IOS_VERSION="26.1"
            log_notice "Selected: $SIMULATOR with iOS $IOS_VERSION for Xcode $XCODE_VERSION"
            ;;
        *)
            SIMULATOR="iPhone 16 Pro" # Default fallback
            IOS_VERSION="18.4"
            log_warning "Unknown Xcode version '$XCODE_VERSION', using default: $SIMULATOR with iOS $IOS_VERSION"
            ;;
    esac
fi
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

MAX_BOOT_ATTEMPTS=5
BOOT_TIMEOUT=180 # 3 minutes

for attempt in $(seq 1 $MAX_BOOT_ATTEMPTS); do
    log_notice "Boot attempt $attempt of $MAX_BOOT_ATTEMPTS"
    
    # Ensure simulator is shutdown before attempting to boot
    if [ "$attempt" -gt 1 ]; then
        log_notice "Shutting down simulator before retry..."
        xcrun simctl shutdown "$UDID" 2>/dev/null || true
        sleep 5
    fi
    
    # Attempt to boot the simulator
    if ! xcrun simctl boot "$UDID" 2>/dev/null; then
        # If boot fails, it might be because the simulator is already booted
        CURRENT_STATE=$(xcrun simctl list devices | grep "$UDID" | sed 's/.*(\([^)]*\)).*$/\1/')
        if [ "$CURRENT_STATE" = "Booted" ]; then
            log_notice "Simulator is already booted"
        else
            log_error "Failed to boot simulator. Current state: $CURRENT_STATE"
            if [ "$attempt" -eq "$MAX_BOOT_ATTEMPTS" ]; then
                exit 1
            fi
            continue
        fi
    else
        log_notice "Simulator boot command executed successfully"
    fi
    
    # Open Simulator app UI (only on first attempt)
    if [ "$attempt" -eq 1 ]; then
        log_notice "Opening Simulator app UI"
        SIMULATOR_APP_PATH="$(xcode-select -p)/Applications/Simulator.app"
        if ! open "$SIMULATOR_APP_PATH"; then
            log_error "Failed to open Simulator app at $SIMULATOR_APP_PATH"
            exit 1
        fi
        log_notice "Simulator app opened successfully"
    fi
    
    # Wait for simulator to fully boot with timeout
    log_notice "Waiting for simulator to fully boot (timeout: ${BOOT_TIMEOUT}s)"
    if run_with_timeout $BOOT_TIMEOUT xcrun simctl bootstatus "$UDID"; then
        log_notice "Simulator boot process completed successfully"
        break
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            log_warning "Simulator boot timed out after ${BOOT_TIMEOUT} seconds"
        else
            log_warning "Simulator bootstatus failed with exit code $EXIT_CODE"
        fi
        
        # Check current state for debugging
        CURRENT_STATE=$(xcrun simctl list devices | grep "$UDID" | sed 's/.*(\([^)]*\)).*$/\1/')
        log_warning "Current simulator state: $CURRENT_STATE"
        
        if [ "$attempt" -eq "$MAX_BOOT_ATTEMPTS" ]; then
            log_error "Failed to boot simulator after $MAX_BOOT_ATTEMPTS attempts"
            exit 1
        fi
        
        log_notice "Will retry booting simulator..."
    fi
done

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
