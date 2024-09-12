#!/usr/bin/env bash

# we need to reset these after copying the modified plist into the app bundle, so we don't
# constantly have updates being committed to the plist in git

/usr/libexec/PlistBuddy -c "Set :GIT_COMMIT_HASH <sha>" "${INFOPLIST_FILE}"
/usr/libexec/PlistBuddy -c "Set :GIT_BRANCH <branch>" "${INFOPLIST_FILE}"
/usr/libexec/PlistBuddy -c "Set :GIT_STATUS_CLEAN <status>" "${INFOPLIST_FILE}"
