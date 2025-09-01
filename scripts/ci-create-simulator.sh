#!/bin/bash
set -euo pipefail

# Usage: ./scripts/ci-create-simulator.sh --platform <platform> --os-version <os_version> --device-name <device_name>
# Example: ./scripts/ci-create-simulator.sh --platform iOS --os-version 26.0 --device-name "iPhone 16e"

PLATFORM=""
OS_VERSION=""
DEVICE_NAME=""

usage() {
  echo "Usage: $0 --platform <platform> --os-version <os_version> --device-name <device_name>"
  echo "  Example: $0 --platform iOS --os-version 26.0 --device-name \"iPhone 16e\""
  exit 1
}

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
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

if [[ -z "$PLATFORM" || -z "$OS_VERSION" || -z "$DEVICE_NAME" ]]; then
  usage
fi

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
    echo "Platform '$PLATFORM' does not require simulator creation or is not supported."
    exit 0
    ;;
esac

# Find the correct runtime identifier
RUNTIME_ID=$(xcrun simctl list runtimes | grep "${SIMCTL_PLATFORM} ${OS_VERSION}" | grep -v unavailable | awk -F '[()]' '{print $2}' | head -n1)

if [[ -z "$RUNTIME_ID" ]]; then
  echo "Could not find runtime for ${SIMCTL_PLATFORM} ${OS_VERSION}"
  xcrun simctl list runtimes
  exit 1
fi

# Check if device already exists
EXISTING_UDID=$(xcrun simctl list devices available | grep "${DEVICE_NAME} (" | grep "${RUNTIME_ID}" | awk -F '[()]' '{print $2}' | head -n1)

if [[ -n "$EXISTING_UDID" ]]; then
  echo "Simulator '${DEVICE_NAME}' for runtime '${SIMCTL_PLATFORM} ${OS_VERSION}' already exists (UDID: $EXISTING_UDID)"
  exit 0
fi

# Create the simulator
echo "Creating simulator: Name='${DEVICE_NAME}', Platform='${SIMCTL_PLATFORM}', OS='${OS_VERSION}'"
NEW_UDID=$(xcrun simctl create "${DEVICE_NAME}" "com.apple.CoreSimulator.SimDeviceType.${DEVICE_NAME// /-}" "$RUNTIME_ID" 2>/dev/null || true)

# If the above fails, try to find the device type identifier
if [[ -z "$NEW_UDID" ]]; then
  DEVICE_TYPE_ID=$(xcrun simctl list devicetypes | grep -i "${DEVICE_NAME}" | awk -F '[()]' '{print $2}' | head -n1)
  if [[ -z "$DEVICE_TYPE_ID" ]]; then
    echo "Could not find device type for '${DEVICE_NAME}'"
    xcrun simctl list devicetypes
    exit 1
  fi
  NEW_UDID=$(xcrun simctl create "${DEVICE_NAME}" "$DEVICE_TYPE_ID" "$RUNTIME_ID")
fi

if [[ -z "$NEW_UDID" ]]; then
  echo "Failed to create simulator for '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION})"
  exit 1
fi

echo "Created simulator '${DEVICE_NAME}' (${SIMCTL_PLATFORM} ${OS_VERSION}) with UDID: $NEW_UDID"
