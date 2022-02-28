#!/bin/bash
set -euo pipefail

# To update the sha run shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m)
EXPECTED="ef3e89f281909766117c179e54dd189c19e302a1a9d8132639f26d390b95ad8f  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. If your changes are intended please update the sha in ./scripts/no-changes-in-high-risk-files.sh."
    exit 1
fi
