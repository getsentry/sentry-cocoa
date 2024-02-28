#!/bin/bash
set -euo pipefail

NEW_CHECKSUM_STATIC=$(shasum -a 256 Carthage/Sentry.xcframework.zip | awk '{print $1}')
NEW_CHECKSUM_DYNAMIC=$(shasum -a 256 Carthage/Sentry-Dynamic.xcframework.zip | awk '{print $1}')

os=$(uname)

if [ "$os" == "Linux" ]; then
    sed -i "s/checksum: \".*\" \/\/Sentry-Static/checksum: \"$NEW_CHECKSUM_STATIC\" \/\/Sentry-Static/" Package.swift
    sed -i "s/checksum: \".*\" \/\/Sentry-Dynamic/checksum: \"$NEW_CHECKSUM_DYNAMIC\" \/\/Sentry-Dynamic/" Package.swift
else
    sed -i "" "s/checksum: \".*\" \/\/Sentry-Static/checksum: \"$NEW_CHECKSUM_STATIC\" \/\/Sentry-Static/" Package.swift
    sed -i "" "s/checksum: \".*\" \/\/Sentry-Dynamic/checksum: \"$NEW_CHECKSUM_DYNAMIC\" \/\/Sentry-Dynamic/" Package.swift
fi

echo $GITHUB_RUN_ID > .github/last-release-runid
