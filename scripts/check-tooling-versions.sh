#!/usr/bin/env bash

REMOTE_CLANG_FORMAT_VERSION=$(cat scripts/.clang-format-version)
REMOTE_SWIFTLINT_VERSION=$(cat scripts/.swiftlint-version)
LOCAL_CLANG_FORMAT_VERSION=$(clang-format --version | awk '{print $3}')
LOCAL_SWIFTLINT_VERSION=$(swiftlint version)
RESOLUTION_MESSAGE="Please run \`make init\` to update your local dev tools. This may actually upgrade to a newer version than what is currently recorded in the lockfile; if that happens, please commit the update to the lockfile as well."

if [ "${LOCAL_CLANG_FORMAT_VERSION}" != "${REMOTE_CLANG_FORMAT_VERSION}" ]; then
    echo "clang-format version mismatch, expected: ${REMOTE_CLANG_FORMAT_VERSION}, but found: ${LOCAL_CLANG_FORMAT_VERSION}. ${RESOLUTION_MESSAGE}"
    exit 1
fi

if [ "${LOCAL_SWIFTLINT_VERSION}" != "${REMOTE_SWIFTLINT_VERSION}" ]; then
    echo "swiftlint version mismatch, expected: ${REMOTE_SWIFTLINT_VERSION}, but found: ${LOCAL_SWIFTLINT_VERSION}. ${RESOLUTION_MESSAGE}"
    exit 1
fi
