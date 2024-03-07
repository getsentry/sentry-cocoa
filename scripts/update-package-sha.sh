#!/bin/bash
set -euo pipefail

if [ -z "$GITHUB_RUN_ID" ]; then
  echo "Error: GITHUB_RUN_ID is not set. Exiting script."
  exit 1
fi

NEW_CHECKSUM_STATIC=$(shasum -a 256 Carthage/Sentry.xcframework.zip | awk '{print $1}')
NEW_CHECKSUM_DYNAMIC=$(shasum -a 256 Carthage/Sentry-Dynamic.xcframework.zip | awk '{print $1}')

os=$(uname)
# Craft pre-release command runs on an ubuntu machine
# and `sed` needs an extra argument for macOS 
if [ "$os" == "Linux" ]; then
    sed -i "s/checksum: \".*\" \/\/Sentry-Static/checksum: \"$NEW_CHECKSUM_STATIC\" \/\/Sentry-Static/" Package.swift
    sed -i "s/checksum: \".*\" \/\/Sentry-Dynamic/checksum: \"$NEW_CHECKSUM_DYNAMIC\" \/\/Sentry-Dynamic/" Package.swift
else
    sed -i "" "s/checksum: \".*\" \/\/Sentry-Static/checksum: \"$NEW_CHECKSUM_STATIC\" \/\/Sentry-Static/" Package.swift
    sed -i "" "s/checksum: \".*\" \/\/Sentry-Dynamic/checksum: \"$NEW_CHECKSUM_DYNAMIC\" \/\/Sentry-Dynamic/" Package.swift
fi

echo $GITHUB_RUN_ID > .github/last-release-runid
