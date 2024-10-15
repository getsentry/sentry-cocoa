#!/bin/bash
# Workaround with a symlink pointed out in: https://github.com/actions/virtual-environments/issues/551#issuecomment-637344435

set -euo pipefail

XCODE_VERSION="${1}"
SIM_RUNTIME="${2}"
DEVICE_TYPE="${3}" # A valid available device type. Find these by running "xcrun simctl list devicetypes".

SIM_RUNTIME_WITH_DASH="${SIM_RUNTIME//./-}"

sudo mkdir -p /Library/Developer/CoreSimulator/Profiles/Runtimes
sudo ln -s "/Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime" "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS ${SIM_RUNTIME}.simruntime"
xcrun simctl create custom-test-device "${DEVICE_TYPE}" "com.apple.CoreSimulator.SimRuntime.iOS-${SIM_RUNTIME_WITH_DASH}"
