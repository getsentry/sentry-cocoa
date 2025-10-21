#!/bin/bash
set -euo pipefail

# Creating simulators takes some time and also cause flakiness. Please use the preinstalled simulators if possible.

# Source CI utility functions for logging and grouping
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "${SCRIPT_DIR}/ci-utils.sh"

# Usage: ./scripts/ci-create-simulator.sh --platform <platform> --os-version <os_version> --device-name <device_name>
# Example: ./scripts/ci-create-simulator.sh --platform iOS --os-version 26.0 --device-name "iPhone 16e"

PLATFORM=""
OS_VERSION=""
DEVICE_NAME=""

usage() {
  log_error "Usage: $0 --platform <platform> --os-version <os_version> --device-name <device_name>"
  log_error "  Example: $0 --platform iOS --os-version 26.0 --device-name \"iPhone 16e\""
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

log_notice "Requested simulator: Platform='$PLATFORM', OS Version='$OS_VERSION', Device Name='$DEVICE_NAME'"

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
    log_notice "Platform '$PLATFORM' does not require simulator creation or is not supported. Skipping."
    exit 0
    ;;
esac

begin_group "Finding runtime for ${SIMCTL_PLATFORM} ${OS_VERSION}"
log_notice "Listing all available runtimes:"
xcrun simctl list runtimes
end_group

begin_group "Finding runtime ID for ${SIMCTL_PLATFORM} ${OS_VERSION}"
RUNTIME_ID=$(xcrun simctl list runtimes | grep "${SIMCTL_PLATFORM} ${OS_VERSION}" | grep -v unavailable | awk '{print $NF}' | head -n1)
if [[ -z "$RUNTIME_ID" ]]; then
  log_error "Could not find runtime for ${SIMCTL_PLATFORM} ${OS_VERSION}"
  xcrun simctl list runtimes
  end_group
  exit 1
fi
log_notice "Found runtime ID: $RUNTIME_ID"
end_group

begin_group "Checking if simulator already exists"
# Use a simpler approach to check for existing simulator
DEVICES_OUTPUT=$(xcrun simctl list devices available 2>/dev/null || true)
EXISTING_UDID=$(echo "$DEVICES_OUTPUT" | grep -A 20 -- "-- ${SIMCTL_PLATFORM} ${OS_VERSION} --" | grep "${DEVICE_NAME} (" | awk -F '[()]' '{print $2}' | head -n1 || true)
if [[ -n "$EXISTING_UDID" ]]; then
  log_notice "Simulator '${DEVICE_NAME}' for runtime '${SIMCTL_PLATFORM} ${OS_VERSION}' already exists (UDID: $EXISTING_UDID)"
  end_group
  exit 0
fi
log_notice "No existing simulator found for '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION})"
end_group

begin_group "Creating simulator"
log_notice "Attempting to create simulator: Name='${DEVICE_NAME}', Platform='${SIMCTL_PLATFORM}', OS='${OS_VERSION}'"
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
  log_notice "Found device type ID: $DEVICE_TYPE_ID"
  NEW_UDID=$(xcrun simctl create "${DEVICE_NAME}" "$DEVICE_TYPE_ID" "$RUNTIME_ID")
fi

if [[ -z "$NEW_UDID" ]]; then
  log_error "Failed to create simulator for '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION})"
  end_group
  exit 1
fi

log_notice "Created simulator '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION}) with UDID: $NEW_UDID"
end_group
