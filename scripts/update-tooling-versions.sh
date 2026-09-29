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

SWIFTLINT_VERSION=$(swiftlint version)
echo "$SWIFTLINT_VERSION" > .swiftlint-version

SWIFTLINT_MODULE_BAZEL="../linters/SwiftLintCustomRules/MODULE.bazel"
if [[ -f "$SWIFTLINT_MODULE_BAZEL" ]]; then
    sed -i '' -E \
        's/(bazel_dep\(name = "swiftlint", version = ")[^"]+(")/\1'"$SWIFTLINT_VERSION"'\2/' \
        "$SWIFTLINT_MODULE_BAZEL"
    # Refresh the lockfile so CI Bazel builds stay in sync with the Homebrew
    # SwiftLint version. `bazel mod deps` is the documented lockfile update.
    (cd ../linters/SwiftLintCustomRules && bazel mod deps --lockfile_mode=update)
fi

xcodegen --version | awk -F ': ' '{print $2}' > .xcodegen-version

# -- End Script --

# Return to original working directory
popd > /dev/null
