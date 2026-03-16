#!/bin/bash

# This script ensures that a required runtime is loaded.
#
# Primary use cases:
# 1. CI sometimes is failing to load some runtimes, this will ensure they are loaded

set -euo pipefail

# Parse named arguments
OS_VERSION=""
PLATFORM=""

usage() {
    echo "Usage: $0 --os-version <os_version> --platform <platform>"
    echo "  OS version: Version to ensure is loaded (e.g., 26.1 for beta, 16.4 for older iOS)"
    echo "  Platform: Platform to ensure is loaded (e.g., iOS, tvOS, visionOS)"
    echo "  Example: $0 --os-version 26.1 --platform iOS"
    echo "  Example: $0 --os-version 16.4"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --os-version)
            OS_VERSION="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [ -z "$OS_VERSION" ]; then
    echo "Error: --os-version argument is required"
    usage
fi

if [ -z "$PLATFORM" ]; then
    echo "Error: --platform argument is required"
    usage
fi

echo "Ensuring runtime $PLATFORM ($OS_VERSION) is loaded"

# Check if the runtime is loaded
if xcrun simctl list runtimes -v | grep -qE "$PLATFORM $OS_VERSION" && ! xcrun simctl list runtimes -v | grep -qE "$PLATFORM $OS_VERSION.*unavailable" ; then
    echo "Runtime $OS_VERSION is loaded"
    exit 0
fi

echo "Runtime $PLATFORM ($OS_VERSION) is not loaded, will try to load it"

# Unmount simulator volumes once before checking
for dir in /Library/Developer/CoreSimulator/Volumes/*; do
    echo "Ejecting $dir"
    sudo diskutil unmount force "$dir" || true
done
sudo launchctl kill -9 system/com.apple.CoreSimulator.simdiskimaged || true
sudo pkill -9 com.apple.CoreSimulator.CoreSimulatorService || true

# Wait for a runtime to be loaded
count=0
MAX_ATTEMPTS=60 # 300 seconds (5 minutes) timeout
while [ $count -lt $MAX_ATTEMPTS ]; do
    if xcrun simctl list runtimes -v | grep -qE "$PLATFORM $OS_VERSION" && ! xcrun simctl list runtimes -v | grep -qE "$PLATFORM $OS_VERSION.*unavailable"; then
        echo "Runtime $OS_VERSION is loaded after $count attempts"
        exit 0
    fi
    echo "Waiting for runtime $OS_VERSION to be loaded... attempt $count"
    count=$((count + 1))
    sleep 5
done

echo "Runtime $PLATFORM ($OS_VERSION) is not loaded after $count attempts"
exit 1
