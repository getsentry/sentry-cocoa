#!/usr/bin/env bash

set -euo pipefail

# Store current working directory
pushd "$(pwd)" > /dev/null
# Change to script directory
cd "${0%/*}"

# -- Begin Script --

REMOTE_CLANG_FORMAT_VERSION=$(cat .clang-format-version)
CLANG_FORMAT_VERSION_STR=$(clang-format --version)

# Xcode's clang-format & Homebrew's LLVM clang-format have prefixes that mean we need to extract the version from the 4th field
# we need to extract the version from the 4th field
case "$CLANG_FORMAT_VERSION_STR" in
    Apple\ *|Homebrew\ *) LOCAL_CLANG_FORMAT_VERSION=$(echo "$CLANG_FORMAT_VERSION_STR" | awk '{print $4}') ;;
    *)                    LOCAL_CLANG_FORMAT_VERSION=$(echo "$CLANG_FORMAT_VERSION_STR" | awk '{print $3}') ;;
esac

REMOTE_SWIFTLINT_VERSION=$(cat .swiftlint-version)
LOCAL_SWIFTLINT_VERSION=$(swiftlint version)

RESOLUTION_MESSAGE="Please run \`make init\` to update your local dev tools. This may actually upgrade to a newer version than what is currently recorded in repo; if that happens, please commit the update to the any lockfiles etc as well."

SENTRY_TOOLING_UP_TO_DATE=true

if [ "${LOCAL_CLANG_FORMAT_VERSION}" != "${REMOTE_CLANG_FORMAT_VERSION}" ]; then
    echo "clang-format version mismatch, expected: ${REMOTE_CLANG_FORMAT_VERSION}, but found: ${LOCAL_CLANG_FORMAT_VERSION}"
    SENTRY_TOOLING_UP_TO_DATE=false
fi

if [ "${LOCAL_SWIFTLINT_VERSION}" != "${REMOTE_SWIFTLINT_VERSION}" ]; then
    echo "swiftlint version mismatch, expected: ${REMOTE_SWIFTLINT_VERSION}, but found: ${LOCAL_SWIFTLINT_VERSION}"
    SENTRY_TOOLING_UP_TO_DATE=false
fi

if ! rbenv version 2>/dev/null; then
    rbenv versions
    SENTRY_TOOLING_UP_TO_DATE=false
fi

if [ $SENTRY_TOOLING_UP_TO_DATE == false ]; then
    echo "${RESOLUTION_MESSAGE}"
    exit 1
fi

# -- End Script --

# Return to original working directory
popd > /dev/null
