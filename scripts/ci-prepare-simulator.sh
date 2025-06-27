#!/bin/bash
# Enhanced simulator preparation script for CI environments
# Addresses hardware keyboard issues, simulator state cleanup, and stability verification

set -euo pipefail

# Parse arguments with defaults optimized for current CI setup
XCODE_VERSION="${1:-16.2}"
PLATFORM="${2:-iOS}"
OS_VERSION="${3:-latest}"
DEVICE="${4:-iPhone 16}"

echo "🚀 Preparing simulator for $PLATFORM $OS_VERSION on $DEVICE with Xcode $XCODE_VERSION"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to wait for simulator with timeout
wait_for_simulator() {
    local simulator_id="$1"
    local timeout="${2:-300}"
    local start_time=$(date +%s)
    
    log "⏳ Waiting for simulator $simulator_id to be ready (timeout: ${timeout}s)..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        
        if [ $elapsed_time -ge $timeout ]; then
            log "❌ Simulator failed to boot within ${timeout} seconds"
            return 1
        fi
        
        if xcrun simctl bootstatus "$simulator_id" 2>/dev/null | grep -q "Boot status: Booted"; then
            log "✅ Simulator is booted and ready"
            return 0
        fi
        
        log "Still waiting... (${elapsed_time}s elapsed)"
        sleep 5
    done
}

# Function to verify simulator responsiveness
verify_simulator_responsiveness() {
    local simulator_id="$1"
    
    log "🔍 Verifying simulator responsiveness..."
    
    # Test 1: Try to get device info
    if ! xcrun simctl getenv "$simulator_id" PATH >/dev/null 2>&1; then
        log "❌ Simulator failed environment test"
        return 1
    fi
    
    # Test 2: Try to launch and terminate a system app
    if xcrun simctl launch "$simulator_id" com.apple.mobilesafari >/dev/null 2>&1; then
        sleep 2
        xcrun simctl terminate "$simulator_id" com.apple.mobilesafari >/dev/null 2>&1 || true
        log "✅ Simulator passed responsiveness test"
        return 0
    else
        log "❌ Simulator failed responsiveness test"
        return 1
    fi
}

# Main execution starts here
log "🧹 Cleaning up existing simulator state..."

# Shutdown all simulators
xcrun simctl shutdown all 2>/dev/null || true

# Clean up old/corrupted simulators
xcrun simctl delete unavailable 2>/dev/null || true

# For CI environments, be more aggressive with cleanup
if [ "${CI:-}" = "true" ]; then
    log "🚨 CI environment detected - performing aggressive cleanup..."
    
    # Delete all existing simulators to ensure clean state
    xcrun simctl list devices -j | jq -r '.devices | to_entries[] | .value[] | select(.isAvailable == true) | .udid' 2>/dev/null | while read -r device_id; do
        log "Deleting simulator: $device_id"
        xcrun simctl delete "$device_id" 2>/dev/null || true
    done
fi

# Map device names to their proper identifiers for simulator creation
case "$DEVICE" in
    "iPhone 14")
        DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-14"
        ;;
    "iPhone 15")
        DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-15"
        ;;
    "iPhone 16")
        DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16"
        ;;
    *)
        DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16"  # Default fallback
        log "⚠️ Unknown device type '$DEVICE', using iPhone 16 as fallback"
        ;;
esac

# Map OS versions to runtime identifiers
if [ "$OS_VERSION" = "latest" ]; then
    case "$XCODE_VERSION" in
        "14.3.1")
            RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.iOS-16-4"
            ;;
        "15.4")
            RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.iOS-17-5"
            ;;
        "16.2"|*)
            RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.iOS-18-2"
            ;;
    esac
else
    # Convert version format (e.g., "17.5" -> "iOS-17-5")
    RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.iOS-${OS_VERSION//./-}"
fi

log "📱 Creating new simulator with device type: $DEVICE_TYPE, runtime: $RUNTIME_ID"

# Create a uniquely named simulator for this CI run
CI_RUN_ID="${GITHUB_RUN_ID:-$(date +%s)}"
SIMULATOR_NAME="CI-${DEVICE// /-}-${OS_VERSION}-${CI_RUN_ID}"

# Create the simulator
SIMULATOR_ID=$(xcrun simctl create "$SIMULATOR_NAME" "$DEVICE_TYPE" "$RUNTIME_ID")
log "✅ Created simulator: $SIMULATOR_ID"

# Boot the simulator
log "🚀 Booting simulator..."
xcrun simctl boot "$SIMULATOR_ID"

# Wait for simulator to be ready with timeout
if ! wait_for_simulator "$SIMULATOR_ID" 300; then
    log "❌ Failed to boot simulator within timeout"
    exit 1
fi

# Configure simulator settings to reduce flakiness
log "⚙️ Configuring simulator settings..."

# Disable hardware keyboard (major source of flakiness in CI)
log "⌨️ Disabling hardware keyboard..."
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false

# Set consistent status bar for screenshots/UI tests
log "📊 Setting up consistent status bar..."
xcrun simctl status_bar "$SIMULATOR_ID" override \
    --time "12:00" \
    --dataNetwork "wifi" \
    --wifiMode "active" \
    --wifiBars "3" \
    --cellularMode "active" \
    --cellularBars "4" \
    --batteryLevel "100" \
    --batteryState "charged"

# Disable location services dialog (can interfere with UI tests)
log "📍 Configuring location services..."
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.locationd LocationServicesEnabled -bool false

# Set up accessibility settings for better test reliability
log "♿ Configuring accessibility settings..."
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.Accessibility ApplicationAccessibilityEnabled -bool true
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true

# Disable auto-lock to prevent screen from locking during tests
log "🔓 Disabling auto-lock..."
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.springboard SBAutoLockTime -int 0

# Configure pasteboard for more predictable behavior
log "📋 Configuring pasteboard..."
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.UIKit UIPasteboardSyncTimeout -int 0

# Verify simulator is responsive before proceeding
if ! verify_simulator_responsiveness "$SIMULATOR_ID"; then
    log "❌ Simulator failed responsiveness check, attempting recovery..."
    
    # Try shutting down and rebooting once
    xcrun simctl shutdown "$SIMULATOR_ID"
    sleep 5
    xcrun simctl boot "$SIMULATOR_ID"
    
    if ! wait_for_simulator "$SIMULATOR_ID" 180; then
        log "❌ Simulator recovery failed"
        exit 1
    fi
    
    if ! verify_simulator_responsiveness "$SIMULATOR_ID"; then
        log "❌ Simulator still unresponsive after recovery attempt"
        exit 1
    fi
fi

# Export simulator ID for use in subsequent CI steps
echo "SIMULATOR_ID=$SIMULATOR_ID" >> "${GITHUB_ENV:-/dev/null}"
echo "SIMULATOR_NAME=$SIMULATOR_NAME" >> "${GITHUB_ENV:-/dev/null}"

log "🎉 Simulator preparation complete!"
log "   Simulator ID: $SIMULATOR_ID"
log "   Simulator Name: $SIMULATOR_NAME"
log "   Device Type: $DEVICE_TYPE"
log "   Runtime: $RUNTIME_ID"

# Output summary for CI logs
echo "::notice title=Simulator Ready::Simulator $SIMULATOR_NAME ($SIMULATOR_ID) is ready for testing"