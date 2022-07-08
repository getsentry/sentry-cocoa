#!/bin/bash

# For available Xcode versions see:
# - https://github.com/actions/virtual-environments/blob/6a2f3acb8890efd4b6ba9344d5f73af25e7a2bcf/images/macos/macos-10.15-Readme.md?plain=1#L254-L266
# - https://github.com/actions/virtual-environments/blob/6a2f3acb8890efd4b6ba9344d5f73af25e7a2bcf/images/macos/macos-11-Readme.md?plain=1#L248-L253

set -euo pipefail

# 13.2.1 is the default
XCODE_VERSION="${1:-13.2.1}"

sudo xcode-select -s /Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer

