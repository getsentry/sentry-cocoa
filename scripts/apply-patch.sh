#!/bin/bash
set -euo pipefail

PULL_REQUEST_SHA="${1}"
GITHUB_SHA="${2}"
PATCH_FILE="${3}"

if [[ "$PULL_REQUEST_SHA" != "" ]]; then
    SHA=$PULL_REQUEST_SHA
else
    SHA=$GITHUB_SHA
fi  

curl "https://raw.githubusercontent.com/getsentry/sentry-cocoa/${SHA}/scripts/${PATCH_FILE}.patch" --output sentry.patch

# Replace revision with SHA
REPLACE="s/__GITHUB_REVISION_PLACEHOLDER__/${SHA}/g"
sed -i '' $REPLACE sentry.patch

git apply sentry.patch
