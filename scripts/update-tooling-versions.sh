#!/usr/bin/env bash

set -euo pipefail

# Store current working directory
pushd "$(pwd)" > /dev/null
# Change to script directory
cd "${0%/*}"

# -- Begin Script --

CLANG_FORMAT_VERSION_STR=$(clang-format --version)
# Xcode's clang-format & Homebrew's LLVM clang-format have prefixes that means
# we need to extract the version from the 4th field
case "$CLANG_FORMAT_VERSION_STR" in
    Apple\ *|Homebrew\ *) echo "$CLANG_FORMAT_VERSION_STR" | awk '{print $4}' > .clang-format-version ;;
    *)                    echo "$CLANG_FORMAT_VERSION_STR" | awk '{print $3}' > .clang-format-version ;;
esac

swiftlint version > .swiftlint-version

# -- End Script --

# Return to original working directory
popd > /dev/null
