#!/bin/bash
set -euo pipefail

# Downloads a patch file from sentry-cocoa and replaces the __GITHUB_REVISION_PLACEHOLDER__ in the patch file
# with the specified git commit hash.
# We use github.event.pull_request.head.sha instead of github.sha when available as 
# the github.sha is the pre merge commit id for PRs.
# See https://github.community/t/github-sha-isnt-the-value-expected/17903/17906.

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
