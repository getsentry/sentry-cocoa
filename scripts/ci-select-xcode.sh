#!/bin/bash

# For available Xcode versions see:
# - https://github.com/actions/virtual-environments/blob/main/images/macos/macos-10.15-Readme.md#xcode
# - https://github.com/actions/virtual-environments/blob/main/images/macos/macos-11-Readme.md#xcode

set -euo pipefail

# 13.2.1 is the default
XCODE_VERSION="${1:-13.2.1}"

sudo xcode-select -s /Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer
swiftc --version
