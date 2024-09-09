#! /usr/bin/env bash

COMMIT_HASH=$(git rev-parse --short HEAD)
/usr/libexec/PlistBuddy -c "Set :GIT_COMMIT_HASH $COMMIT_HASH" "${INFOPLIST_FILE}"

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
/usr/libexec/PlistBuddy -c "Set :GIT_BRANCH $BRANCH_NAME" "${INFOPLIST_FILE}"

GIT_STATUS_CLEAN=$(test -n "$(git status --porcelain)")
/usr/libexec/PlistBuddy -c "Set :GIT_STATUS_CLEAN $GIT_STATUS_CLEAN" "${INFOPLIST_FILE}"
