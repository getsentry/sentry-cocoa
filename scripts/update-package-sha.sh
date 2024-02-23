#!/bin/bash
set -euo pipefail

GITHUB_BRANCH="${1}"
NEW_CHECKSUM=$(shasum ${2} | awk '{print $1}')

sed -i '' "s/checksum: \".*\"/checksum: \"$NEW_CHECKSUM\"/" "Package.swift"

echo "Updating Package.swift framework SHA"
git config --global user.email "bot+github-bot@sentry.io"
git config --global user.name "Sentry Github Bot"
git add .
git commit -m "Update Package.swift framework SHA"
git push origin $GITHUB_BRANCH
