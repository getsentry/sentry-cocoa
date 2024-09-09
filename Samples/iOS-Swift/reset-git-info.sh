#!/usr/bin/env bash

# we need to reset these after copying the modified plist into the app bundle, so we don't
# constantly have updates being committed to the plist in git

/usr/libexec/PlistBuddy -c "Set :GIT_COMMIT_HASH $COMMIT_HASH" "${INFOPLIST_FILE}"
/usr/libexec/PlistBuddy -c "Set :GIT_BRANCH $BRANCH_NAME" "${INFOPLIST_FILE}"
/usr/libexec/PlistBuddy -c "Set :GIT_STATUS_CLEAN $GIT_STATUS_CLEAN" "${INFOPLIST_FILE}"
