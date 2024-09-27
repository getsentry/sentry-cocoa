#!/usr/bin/env bash

set -x

GIT_STATUS_CLEAN=1
if test -n "$(git status --porcelain)"; then
    GIT_STATUS_CLEAN=0
fi
/usr/libexec/PlistBuddy -c "Set :GIT_STATUS_CLEAN $GIT_STATUS_CLEAN" "${INFOPLIST_FILE}"

COMMIT_HASH=$(git rev-parse --short HEAD)
/usr/libexec/PlistBuddy -c "Set :GIT_COMMIT_HASH $COMMIT_HASH" "${INFOPLIST_FILE}"

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
/usr/libexec/PlistBuddy -c "Set :GIT_BRANCH $BRANCH_NAME" "${INFOPLIST_FILE}"
