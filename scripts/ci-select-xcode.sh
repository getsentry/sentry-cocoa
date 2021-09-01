#!/bin/bash

# For available Xcode versions on Github Action, see 
# https://github.com/actions/virtual-environments/blob/main/images/macos/macos-11-Readme.md#xcode

set -euo pipefail

# 12.5.1 is the default
XCODE_VERSION="${1:-12.5.1}"

sudo xcode-select -s /Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer

