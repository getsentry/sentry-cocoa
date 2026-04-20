#!/usr/bin/env bash

set -euo pipefail

# Store current working directory
pushd "$(pwd)" > /dev/null
# Change to script directory
cd "${0%/*}"

# -- Begin Script --

clang-format --version | grep -Eo '[0-9]+(\.[0-9]+)+' | head -n1 > .clang-format-version
swiftlint version > .swiftlint-version

# -- End Script --

# Return to original working directory
popd > /dev/null
