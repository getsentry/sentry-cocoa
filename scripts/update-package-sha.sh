#!/bin/bash
set -euo pipefail

NEW_CHECKSUM=$(shasum -a 256 Carthage/Sentry.xcframework.zip | awk '{print $1}')

os=$(uname)

if [ "$os" == "Linux" ]; then
    sed -i "s/checksum: \".*\"/checksum: \"$NEW_CHECKSUM\"/" Package.swift
else
    sed -i "" "s/checksum: \".*\"/checksum: \"$NEW_CHECKSUM\"/" Package.swift
fi

echo $GITHUB_RUN_ID > .github/last-release-runid
