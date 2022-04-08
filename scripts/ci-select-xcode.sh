#!/bin/bash

# For available Xcode versions on Github Action, see 
# https://github.com/actions/virtual-environments/blob/main/images/macos/macos-11-Readme.md#xcode
# Although https://github.com/actions/virtual-environments/tree/main/images/macos has readmes on
# macOS-10.14 and macOS-10.13 only macOS-10.15 and macOS-11 are working. When using macOS-10.14 or
# macOS-10.13 GitHub Actions never find a runner and the job keeps hanging until it times out.

set -euo pipefail

# 13.2.1 is the default
XCODE_VERSION="${1:-13.2.1}"

sudo xcode-select -s /Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer

