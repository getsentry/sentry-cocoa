#!/bin/bash

set -euo pipefail

# Launches the SwiftUI Crash Test app and validates that it crashes and relaunches correctly.
# This test run requires one booted simulator to work. So make sure to boot one simulator before running this script.

BUNDLE_ID="io.sentry.sentry.SwiftUICrashTest"
USER_DEFAULT_KEY="crash-on-launch"
DEVICE_ID="booted"

echo "Starting crash test and relaunch test."
echo "This test crashes the app and validates that it can relaunch after a crash without crashing again."


echo "🔨 Building SwiftUI Crash Test app for simulator 🔨"

xcodebuild -workspace Sentry.xcworkspace -scheme SwiftUICrashTest -destination "platform=iOS Simulator,name=iPhone 16" -derivedDataPath DerivedData -configuration Debug CODE_SIGNING_REQUIRED=NO build

echo "Installing app on simulator..."
xcrun simctl install $DEVICE_ID DerivedData/Build/Products/Debug-iphonesimulator/SwiftUICrashTest.app

echo "Terminating app if running..."
xcrun simctl terminate $DEVICE_ID $BUNDLE_ID 2>/dev/null || true

# Phase 1: Let the app crash

echo "Setting crash flag..."
xcrun simctl spawn $DEVICE_ID defaults write $BUNDLE_ID $USER_DEFAULT_KEY -bool true

echo "Launching app with expected crash."
xcrun simctl launch $DEVICE_ID $BUNDLE_ID > /dev/null 2>&1 &

# Check every 100ms for 5 seconds if the app is still running.
for i in {1..50}; do
    if xcrun simctl listapps $DEVICE_ID | grep "$BUNDLE_ID" | grep -q "Running"; then
        sleep 0.1
    else
        echo "✅ App crashed as expected after $(echo "scale=1; $i * 0.1" | bc) seconds."
        break
    fi
    
    if [ "$i" -eq 50 ]; then
        echo "❌ App is still running after 5 seconds but it should have crashed instead."
        exit 1
    fi
done

# Phase 2: Test normal operation

echo "Removing crash flag..."
xcrun simctl spawn $DEVICE_ID defaults delete $BUNDLE_ID $USER_DEFAULT_KEY 2>/dev/null || true

echo "Relaunching app after crash."
xcrun simctl launch $DEVICE_ID $BUNDLE_ID > /dev/null 2>&1

sleep 5

# Check if app is still running

if xcrun simctl spawn booted launchctl list | grep "$BUNDLE_ID"; then
    echo "✅ App is still running"
else
    echo "❌ App is not running"
    exit 1
fi

echo "Terminating app..."
xcrun simctl terminate $DEVICE_ID $BUNDLE_ID 2>/dev/null || true

echo "✅ Test completed successfully!" 
exit 0
