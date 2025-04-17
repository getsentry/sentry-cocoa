#!/bin/bash

# For available Xcode versions see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md

set -euo pipefail

XCODE_VERSION="${1}"

# We prefer this over calling `sudo xcode-select` because it will fail if the Xcode version
# is not installed. Also xcodes is preinstalled on the GH runners.
xcodes select "$XCODE_VERSION"
swiftc --version
