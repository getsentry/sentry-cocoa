#!/bin/bash

# We boot the simulator because the GitHub Actions runner sometimes fails to launch the simulator.
# We do this manually to know immediately if the simulator is not booting.
# Because otherwise we compile the tests first and then try to boot the simulator.

# For available Xcode and simulator versions see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md

set -euo pipefail

XCODE_VERSION="${1:-16.2}"

# Select simulator based on Xcode version
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

xcrun simctl boot "$SIMULATOR"
