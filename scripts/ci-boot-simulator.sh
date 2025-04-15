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

# Only allow one argument type
if [[ $# -gt 2 ]]; then
    echo "Error: Cannot specify both --xcode and --device"
    echo "Usage: $0 [-x|--xcode <version>] OR [-d|--device <device>]"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -x|--xcode)
            XCODE_VERSION="$2"
            shift 2
            ;;
        -d|--device)
            SIMULATOR="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [-x|--xcode <version>] [-d|--device <device>]"
            exit 1
            ;;
    esac
done

# Select simulator based on Xcode version
if [[ -z "${SIMULATOR}" ]]; then
    case "$XCODE_VERSION" in
        "14.3.1")
            SIMULATOR="iPhone 14"
            ;;
        "15.4")
            SIMULATOR="iPhone 15"
            ;;
        "16.2")
            SIMULATOR="iPhone 16"
            ;;
        *)
            SIMULATOR="iPhone 16" # Default fallback
            ;;
    esac
fi

echo "Booting simulator $SIMULATOR"
xcrun simctl boot "$SIMULATOR"

# Print details about the booted simulator, iOS version, etc.
xcrun simctl list devices --json | jq '.devices | to_entries[] | select(.value[] | .state == "Booted")'
