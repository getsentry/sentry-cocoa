#!/bin/bash

# We boot the simulator because the GitHub Actions runner sometimes fails to launch the simulator.
# We do this manually to know immediately if the simulator is not booting.
# Because otherwise we compile the tests first and then try to boot the simulator.

# For available Xcode and simulator versions see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md

set -euo pipefail

# Parse named arguments
XCODE_VERSION="16.2" # Default value

while [[ $# -gt 0 ]]; do
    case $1 in
        -x|--xcode)
            XCODE_VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [-x|--xcode <version>]"
            exit 1
            ;;
    esac
done

SIMULATOR="iPhone 16"
IOS_VERSION="18.5"

# Select simulator based on Xcode version
case "$XCODE_VERSION" in
    "14.3.1")
        SIMULATOR="iPhone 14"
        IOS_VERSION="16.4"
        ;;
    "15.4")
        SIMULATOR="iPhone 15"
        IOS_VERSION="17.5"
        ;;
    "16.2")
        SIMULATOR="iPhone 16"
        IOS_VERSION="18.5"
        ;;
    *)
        SIMULATOR="iPhone 16" # Default fallback
        IOS_VERSION="18.5"
        ;;
esac

UDID=$(xcrun simctl list devices available | \
grep -A 5 "^-- iOS $IOS_VERSION --" | \
grep "$SIMULATOR (" | \
sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p' | \
head -n1)

echo "Booting simulator $SIMULATOR - iOS $IOS_VERSION: $UDID"
xcrun simctl boot "$UDID"

# We use `open -a Simulator` because there's no lower-level CLI like `simctl` to display the simulator UI available.
open -a Simulator

# Wait for the simulator to boot
# We need to wait for the simulator to boot to avoid the test to fail due to timeout (because the simulator is not booted yet)
xcrun simctl bootstatus "$UDID"

# Print details about the booted simulator, iOS version, etc.
xcrun simctl list devices --json | jq '.devices | to_entries[] | select(.value[] | .state == "Booted")'
