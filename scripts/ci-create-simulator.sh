#!/bin/bash
set -euo pipefail

# Creating simulators takes some time and also cause flakiness. Please use the preinstalled simulators if possible.

# Source CI utility functions for logging and grouping
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "${SCRIPT_DIR}/ci-utils.sh"


PLATFORM=""
OS_VERSION=""
DEVICE_NAME=""

usage() {
  cat <<EOF
Usage: $(basename "$0") --platform <platform> --os-version <os_version> --device-name <device_name>

Create a simulator for the given platform, OS version, and device name.

OPTIONS:
    --platform <platform>       Target platform: iOS, tvOS, or visionOS
    --os-version <os_version>   Simulator OS version, e.g. '26.1' or '16.4'
    --device-name <device_name> Device name, e.g. 'iPhone 17 Pro'

EXAMPLES:
    $(basename "$0") --platform iOS --os-version 26.1 --device-name "iPhone 17 Pro"
    $(basename "$0") --platform iOS --os-version 16.4 --device-name "iPhone 14 Pro"

EOF
  exit 1
}

begin_group "Parsing arguments for simulator creation"
while [[ $# -gt 0 ]]; do
  case $1 in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --os-version)
      OS_VERSION="$2"
      shift 2
      ;;
    --device-name)
      DEVICE_NAME="$2"
      shift 2
      ;;
    *)
      log_error "Unknown argument: $1"
      usage
      ;;
  esac
done
end_group

if [[ -z "$PLATFORM" || -z "$OS_VERSION" || -z "$DEVICE_NAME" ]]; then
  usage
fi

echo "Requested simulator: Platform='$PLATFORM', OS Version='$OS_VERSION', Device Name='$DEVICE_NAME'"

# Map platform to simctl device type and runtime
case "$PLATFORM" in
  iOS)
    SIMCTL_PLATFORM="iOS"
    ;;
  tvOS)
    SIMCTL_PLATFORM="tvOS"
    ;;
  visionOS)
    SIMCTL_PLATFORM="visionOS"
    ;;
  *)
    echo "Platform '$PLATFORM' does not require simulator creation or is not supported. Skipping."
    exit 0
    ;;
esac

begin_group "Finding runtime for ${SIMCTL_PLATFORM} ${OS_VERSION}"
echo "Listing all available runtimes:"
xcrun simctl list runtimes
end_group

# simctl text output uses major.minor in display names (e.g. "iOS 26.4") even
# for hotfix versions like 26.4.1. Extract major.minor for text matching.
VERSION_MM=$(echo "$OS_VERSION" | awk -F. '{print $1"."$2}')

begin_group "Finding runtime ID for ${SIMCTL_PLATFORM} ${OS_VERSION}"
RUNTIME_ID=$(xcrun simctl list runtimes | grep "${SIMCTL_PLATFORM} ${VERSION_MM}" | grep -v unavailable | awk '{print $NF}' | head -n1)
if [[ -z "$RUNTIME_ID" ]]; then
  log_error "Could not find runtime for ${SIMCTL_PLATFORM} ${OS_VERSION}"
  xcrun simctl list runtimes
  end_group
  exit 1
fi
echo "Found runtime ID: $RUNTIME_ID"
end_group

begin_group "Checking if simulator already exists"
# Use a simpler approach to check for existing simulator
DEVICES_OUTPUT=$(xcrun simctl list devices available 2>/dev/null || true)
EXISTING_UDID=$(echo "$DEVICES_OUTPUT" | grep -A 20 -- "-- ${SIMCTL_PLATFORM} ${VERSION_MM} --" | grep "${DEVICE_NAME} (" | awk -F '[()]' '{print $2}' | head -n1 || true)
if [[ -n "$EXISTING_UDID" ]]; then
  echo "Simulator '${DEVICE_NAME}' for runtime '${SIMCTL_PLATFORM} ${OS_VERSION}' already exists (UDID: $EXISTING_UDID)"
  end_group
  exit 0
fi
echo "No existing simulator found for '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION})"
end_group

begin_group "Creating simulator"
echo "Attempting to create simulator: Name='${DEVICE_NAME}', Platform='${SIMCTL_PLATFORM}', OS='${OS_VERSION}'"
NEW_UDID=$(xcrun simctl create "${DEVICE_NAME}" "com.apple.CoreSimulator.SimDeviceType.${DEVICE_NAME// /-}" "$RUNTIME_ID" 2>/dev/null || true)

# If the above fails, try to find the device type identifier
if [[ -z "$NEW_UDID" ]]; then
  log_warning "Default device type identifier failed, searching for device type ID for '${DEVICE_NAME}'"
  DEVICE_TYPE_ID=$(xcrun simctl list devicetypes | grep -i "${DEVICE_NAME}" | awk -F '[()]' '{print $2}' | head -n1)
  if [[ -z "$DEVICE_TYPE_ID" ]]; then
    log_error "Could not find device type for '${DEVICE_NAME}'"
    xcrun simctl list devicetypes
    end_group
    exit 1
  fi
  echo "Found device type ID: $DEVICE_TYPE_ID"
  NEW_UDID=$(xcrun simctl create "${DEVICE_NAME}" "$DEVICE_TYPE_ID" "$RUNTIME_ID")
fi

if [[ -z "$NEW_UDID" ]]; then
  log_error "Failed to create simulator for '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION})"
  end_group
  exit 1
fi

echo "Created simulator '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION}) with UDID: $NEW_UDID"
end_group
