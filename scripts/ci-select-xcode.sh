#!/bin/bash

# For available Xcode versions see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md

set -euo pipefail

XCODE_VERSION="${1:}"

if [ -z "$XCODE_VERSION" ]; then
  echo "XCODE_VERSION is not set"
  exit 1
fi

sudo xcode-select -s "/Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer"
swiftc --version
