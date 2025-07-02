#!/bin/bash

set -euo pipefail

# Launches the SwiftUI Crash Test app and validates that it crashes and relaunches correctly.
# This test run requires one booted simulator to work. So make sure to boot one simulator before
# running this script.

# Background:
# XCTest isn't built for crashing during tests. Instead of using XCTest to press a button and
# let a test app crash, we now use UserDefaults to tell the test app to crash during launch.
# We then simply launch the app again via `xcrun simctl launch` and wait to see if it keeps
# running. This is basically the same as the testCrash of the SwiftUITestSample without using
# XCTests.


BUNDLE_ID="io.sentry.tests.SwiftUICrashTest"
USER_DEFAULT_KEY="crash-on-launch"
DEVICE_ID="booted"
SCREENSHOTS_DIR="test-crash-and-relaunch-simulator-screenshots"

usage() {
    echo "Usage: $0"
    echo "  -s|--screenshots-dir <dir>      Screenshots directory (default: test-crash-and-relaunch-simulator-screenshots)"
    echo "  -h|--help                       Show this help message"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--screenshots-dir)
            SCREENSHOTS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Echo with timestamp
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Take screenshot with timestamp and custom name
take_simulator_screenshot() {
    local name="$1"
    
    # Create screenshots directory if it doesn't exist
    mkdir -p "$SCREENSHOTS_DIR"
    
    # Generate timestamp-based filename with custom name
    timestamp=$(date '+%H%M%S')
    screenshot_name="$SCREENSHOTS_DIR/${timestamp}_${name}.png"
    
    # Take screenshot
    xcrun simctl io booted screenshot "$screenshot_name" 2>/dev/null || true
}

log "Removing previous screenshots directory."
rm -rf "$SCREENSHOTS_DIR"

log "Starting crash test and relaunch test."
log "This test crashes the app and validates that it can relaunch after a crash without crashing again."

log "🔨 Building SwiftUI Crash Test app for simulator 🔨"

xcodebuild -workspace Sentry.xcworkspace \
    -scheme SwiftUICrashTest \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -derivedDataPath DerivedData \
    -configuration Debug \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | tee raw-build.log | xcbeautify

log "Installing app on simulator."
xcrun simctl install $DEVICE_ID DerivedData/Build/Products/Debug-iphonesimulator/SwiftUICrashTest.app

take_simulator_screenshot "after-install"

log "Terminating app if running."
xcrun simctl terminate $DEVICE_ID $BUNDLE_ID 2>/dev/null || true

# Phase 1: Let the app crash

log "Setting crash flag."
xcrun simctl spawn $DEVICE_ID defaults write $BUNDLE_ID $USER_DEFAULT_KEY -bool true

log "Launching app with expected crash."
xcrun simctl launch $DEVICE_ID $BUNDLE_ID

# Check every 100ms for 5 seconds if the app is still running.
for i in {1..50}; do
    if xcrun simctl listapps $DEVICE_ID | grep "$BUNDLE_ID" | grep -q "Running"; then
        sleep 0.1
    else
        log "✅ App crashed as expected after $(echo "scale=1; $i * 0.1" | bc) seconds."
        break
    fi
    
    if [ "$i" -eq 50 ]; then
        log "❌ App is still running after 5 seconds but it should have crashed instead."
        exit 1
    fi
done

take_simulator_screenshot "after-crash"

# Phase 2: Test normal operation

log "Removing crash flag..."
xcrun simctl spawn $DEVICE_ID defaults delete $BUNDLE_ID $USER_DEFAULT_KEY

log "Relaunching app after crash."
xcrun simctl launch $DEVICE_ID $BUNDLE_ID

take_simulator_screenshot "after-crash-check"

log "Waiting for 5 seconds to check if the app is still running."
sleep 5

take_simulator_screenshot "after-crash-check-after-sleep"

if xcrun simctl spawn booted launchctl list | grep "$BUNDLE_ID"; then
    log "✅ App is still running"
else
    log "❌ App is not running"    
    exit 1
fi

log "✅ Test completed successfully." 
exit 0
