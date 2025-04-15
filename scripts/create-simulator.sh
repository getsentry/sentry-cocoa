#!/bin/bash
# Workaround with a symlink pointed out in: https://github.com/actions/virtual-environments/issues/551#issuecomment-637344435

set -euo pipefail

XCODE_VERSION="${1}"
SIM_RUNTIME="${2}"
DEVICE_TYPE="${3}" # A valid available device type. Find these by running "xcrun simctl list devicetypes".
FORCE_SIM_RUNTIME="${4}"

SIM_RUNTIME_WITH_DASH="${SIM_RUNTIME//./-}"
SIM_NAME="Sentry ${DEVICE_TYPE} (${SIM_RUNTIME})"

if [ "${FORCE_SIM_RUNTIME}" == "true" ]; then
  sudo mkdir -p /Library/Developer/CoreSimulator/Profiles/Runtimes
  sudo ln -s \
    "/Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime" \
    "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS ${SIM_RUNTIME}.simruntime"
fi

uuid=$(xcrun simctl create \
  "${SIM_NAME}" \
  "${DEVICE_TYPE}" \
  "com.apple.CoreSimulator.SimRuntime.iOS-${SIM_RUNTIME_WITH_DASH}")
echo "Created simulator ${SIM_NAME} with UUID ${uuid}"

xcrun simctl boot "${uuid}"
xcrun simctl bootstatus "${uuid}"
echo "Booted simulator ${SIM_NAME} with UUID ${uuid}"

if [ -n "${GITHUB_ENV}" ]; then
  echo "SENTRY_SIMULATOR_UUID=${uuid}" >> "${GITHUB_ENV}"
fi
