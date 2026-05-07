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
        count=$((count + 1))
    done
    
    # Get the exit code of the command
    wait $pid
    return $?
}

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Boot a simulator for CI testing. Retries on failure with timeout.

OPTIONS:
    -x, --xcode <version>        Xcode version for fallback device selection (default: 16.2)
    -d, --device <device_name>   Device name, e.g. 'iPhone 16 Pro'
    -o, --os-version <version>   Simulator OS version, e.g. '18.2'
    -p, --platform <platform>    Target platform (default: iOS)

EXAMPLES:
    $(basename "$0") -d "iPhone 16 Pro" -o 18.2 -p iOS
    $(basename "$0") -x 26.1

EOF
    exit 1
}

# Parse named arguments
XCODE_VERSION="16.2" # Default value
DEVICE_NAME=""
OS_VERSION=""
PLATFORM="iOS"

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
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            ;;
    esac
done

echo "Starting simulator boot process with Xcode version: $XCODE_VERSION"

begin_group "Simulator Selection"

# If device and OS version are provided, use them directly
if [ -n "$DEVICE_NAME" ] && [ -n "$OS_VERSION" ] && [ -n "$PLATFORM" ]; then
    SIMULATOR="$DEVICE_NAME"
    PLATFORM_VERSION="$OS_VERSION"
    PLATFORM_NAME="$PLATFORM"
    echo "Using provided parameters: $SIMULATOR with $PLATFORM_NAME $PLATFORM_VERSION"
else
    # Fallback to Xcode version-based selection for backward compatibility
    SIMULATOR="iPhone 16 Pro"
    PLATFORM_VERSION="18.5"
    PLATFORM_NAME="iOS"

    # Select simulator based on Xcode version
    case "$XCODE_VERSION" in
        "16.2")
            SIMULATOR="iPhone 16 Pro"
            PLATFORM_VERSION="18.2"
            PLATFORM_NAME="iOS"
            echo "Selected: $SIMULATOR with $PLATFORM_NAME $PLATFORM_VERSION for Xcode $XCODE_VERSION"
            ;;
        "26.1")
            SIMULATOR="iPhone 17 Pro"
            PLATFORM_VERSION="26.1"
            PLATFORM_NAME="iOS"
            echo "Selected: $SIMULATOR with $PLATFORM_NAME $PLATFORM_VERSION for Xcode $XCODE_VERSION"
            ;;
        *)
            SIMULATOR="iPhone 16 Pro" # Default fallback
            PLATFORM_VERSION="18.4"
            PLATFORM_NAME="iOS"
            log_warning "Unknown Xcode version '$XCODE_VERSION', using default: $SIMULATOR with $PLATFORM_NAME $PLATFORM_VERSION"
            ;;
    esac
fi
end_group

begin_group "Available Devices"
echo "Listing all available simulators:"
xcrun simctl list devices available
end_group

begin_group "Device Discovery"
echo "Searching for simulator: $SIMULATOR running $PLATFORM_NAME $PLATFORM_VERSION"

# simctl device headers use major.minor (e.g. "-- iOS 26.4 --") even for
# hotfix versions like 26.4.1. Extract major.minor for section matching.
VERSION_MM=$(echo "$PLATFORM_VERSION" | awk -F. '{print $1"."$2}')

UDID=$(xcrun simctl list devices available | \
awk -v platform="$PLATFORM_NAME" -v version="$VERSION_MM" '
  $0 ~ "^-- " platform " " version " --" { in_section = 1; next }
  in_section { if (/^-- /) exit; print }
' | \
grep "$SIMULATOR (" | \
sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p' | \
head -n1)

if [ -z "$UDID" ]; then
    AVAILABLE_DEVICES=$(xcrun simctl list devices available)
    log_error "Failed to find UDID for simulator: $SIMULATOR with $PLATFORM_NAME $PLATFORM_VERSION.%0A%0AAvailable devices:%0A${AVAILABLE_DEVICES//$'\n'/%0A}"
    exit 1
fi

echo "Found simulator UDID: $UDID"
end_group

begin_group "Simulator Boot"
echo "Booting simulator: $SIMULATOR - $PLATFORM_NAME $PLATFORM_VERSION (UDID: $UDID)"

MAX_BOOT_ATTEMPTS=5
BOOT_TIMEOUT=180 # 3 minutes

for attempt in $(seq 1 $MAX_BOOT_ATTEMPTS); do
    echo "Boot attempt $attempt of $MAX_BOOT_ATTEMPTS"
    
    # Ensure simulator is shutdown before attempting to boot
    if [ "$attempt" -gt 1 ]; then
        echo "Shutting down simulator before retry..."
        xcrun simctl shutdown "$UDID" 2>/dev/null || true
        sleep 5
    fi
    
    # Attempt to boot the simulator
    if ! xcrun simctl boot "$UDID" 2>/dev/null; then
        # If boot fails, it might be because the simulator is already booted
        CURRENT_STATE=$(xcrun simctl list devices | grep "$UDID" | sed 's/.*(\([^)]*\)).*$/\1/')
        if [ "$CURRENT_STATE" = "Booted" ]; then
            echo "Simulator is already booted"
        else
            log_error "Failed to boot simulator. Current state: $CURRENT_STATE"
            if [ "$attempt" -eq "$MAX_BOOT_ATTEMPTS" ]; then
                exit 1
            fi
            continue
        fi
    else
        echo "Simulator boot command executed successfully"
    fi
    
    # Open Simulator app UI (only on first attempt)
    if [ "$attempt" -eq 1 ]; then
        echo "Opening Simulator app UI"
        SIMULATOR_APP_PATH="$(xcode-select -p)/Applications/Simulator.app"
        if ! open "$SIMULATOR_APP_PATH"; then
            log_error "Failed to open Simulator app at $SIMULATOR_APP_PATH"
            exit 1
        fi
        echo "Simulator app opened successfully"
    fi
    
    # Wait for simulator to fully boot with timeout
    echo "Waiting for simulator to fully boot (timeout: ${BOOT_TIMEOUT}s)"
    if run_with_timeout $BOOT_TIMEOUT xcrun simctl bootstatus "$UDID"; then
        echo "Simulator boot process completed successfully"
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
        
        echo "Will retry booting simulator..."
    fi
done

end_group

begin_group "Booted Device Details"
echo "Listing all currently booted simulators:"
if ! xcrun simctl list devices --json | jq '.devices | to_entries[] | select(.value[] | .state == "Booted")'; then
    echo "Failed to retrieve booted device details (jq might not be available)"
    echo "Fallback: listing devices without JSON formatting"
    xcrun simctl list devices | grep "Booted"
fi
end_group

echo "Simulator boot process completed successfully!"
