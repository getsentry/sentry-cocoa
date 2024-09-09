#!/usr/bin/env bash

set -x

# if we don't supply the default happy path value, this variable
# will be empty if `test` below returns a result of no modifications
# to the index, which will be interpreted as a falsy value in the
# swift code
GIT_STATUS_CLEAN=1
GIT_STATUS_CLEAN=$(test -n "$(git status --porcelain)")
/usr/libexec/PlistBuddy -c "Set :GIT_STATUS_CLEAN $GIT_STATUS_CLEAN" "${INFOPLIST_FILE}"

COMMIT_HASH=$(git rev-parse --short HEAD)
/usr/libexec/PlistBuddy -c "Set :GIT_COMMIT_HASH $COMMIT_HASH" "${INFOPLIST_FILE}"

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
/usr/libexec/PlistBuddy -c "Set :GIT_BRANCH $BRANCH_NAME" "${INFOPLIST_FILE}"
