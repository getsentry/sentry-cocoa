#!/usr/bin/env bash

echo "Checking if a simulator is booted..."
if ! xcrun simctl list devices | grep -q "(Booted)"; then
    echo "No simulator is currently booted. Please boot a simulator before running this script."
    exit 1
fi

echo "Installing gems..."
bundle install

echo "Building the sample app..."
bundle exec fastlane build_ios_swift_ui_test_sample

echo "Installing the sample app on the simulator..."
appPath="TestSamples/SwiftUITestSample/DerivedData/Build/Products/Debug-iphonesimulator/SwiftUITestSample.app"
xcrun simctl install booted "$appPath"

echo "Running the Maestro tests..."
maestro test TestSamples/SwiftUITestSample/Maestro --debug-output TestSamples/SwiftUITestSample/MaestroLogs
