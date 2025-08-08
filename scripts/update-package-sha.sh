#!/bin/bash
set -euo pipefail

if [ -z "$GITHUB_RUN_ID" ]; then
  echo "Error: GITHUB_RUN_ID is not set. Exiting script."
  exit 1
fi

PACKAGE_FILES=$(find . -maxdepth 1 -name "Package.swift" -o -name "Package@swift-*.swift" | sort)

if [ -z "$PACKAGE_FILES" ]; then
    echo "::error::No Package.swift or Package@swift-*.swift files found"
    exit 1
fi

NEW_CHECKSUM_STATIC=$(shasum -a 256 Carthage/Sentry.xcframework.zip | awk '{print $1}')
NEW_CHECKSUM_DYNAMIC=$(shasum -a 256 Carthage/Sentry-Dynamic.xcframework.zip | awk '{print $1}')

os=$(uname)

for package_file in $PACKAGE_FILES; do
  # Craft pre-release command runs on an ubuntu machine
  # and `sed` needs an extra argument for macOS 
  if [ "$os" == "Linux" ]; then
      sed -i "s/checksum: \".*\" \/\/Sentry-Static/checksum: \"$NEW_CHECKSUM_STATIC\" \/\/Sentry-Static/" "$package_file"
      sed -i "s/checksum: \".*\" \/\/Sentry-Dynamic/checksum: \"$NEW_CHECKSUM_DYNAMIC\" \/\/Sentry-Dynamic/" "$package_file"
  else
      sed -i "" "s/checksum: \".*\" \/\/Sentry-Static/checksum: \"$NEW_CHECKSUM_STATIC\" \/\/Sentry-Static/" "$package_file"
      sed -i "" "s/checksum: \".*\" \/\/Sentry-Dynamic/checksum: \"$NEW_CHECKSUM_DYNAMIC\" \/\/Sentry-Dynamic/" "$package_file"
  fi
done

echo "$GITHUB_RUN_ID" > .github/last-release-runid
