#!/usr/bin/env bash

BREW_CLANG_FORMAT_VERSION=$(jq '.entries.brew."clang-format".version' Brewfile.lock.json | sed s/'"'//g)
BREW_SWIFTLINT_VERSION=$(jq '.entries.brew.swiftlint.version' Brewfile.lock.json | sed s/'"'//g)
LOCAL_CLANG_FORMAT_VERSION=$(clang-format --version | awk '{print $3}')
LOCAL_SWIFTLINT_VERSION=$(swiftlint version)
RESOLUTION_MESSAGE="Please run \`make init\` to update your local dev tools. This may actually upgrade to a newer version than what is currently recorded in the lockfile; if that happens, please commit the update to the lockfile as well."

if [ "${LOCAL_CLANG_FORMAT_VERSION}" != "${BREW_CLANG_FORMAT_VERSION}" ]; then
    echo "clang-format version mismatch, expected: ${BREW_CLANG_FORMAT_VERSION}, but found: ${LOCAL_CLANG_FORMAT_VERSION}. ${RESOLUTION_MESSAGE}"
    exit 1
fi

if [ "${LOCAL_SWIFTLINT_VERSION}" != "${BREW_SWIFTLINT_VERSION}" ]; then
    echo "swiftlint version mismatch, expected: ${BREW_SWIFTLINT_VERSION}, but found: ${LOCAL_SWIFTLINT_VERSION}. ${RESOLUTION_MESSAGE}"
    exit 1
fi
