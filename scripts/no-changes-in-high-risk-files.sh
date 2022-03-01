#!/bin/bash
set -euo pipefail

# To update the sha run shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m)
EXPECTED="e07d82b30d1b66c75c1722c7c5b17be1dc273aaaaba749c14537d902eda38d4c  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. If your changes are intended please update the sha in ./scripts/no-changes-in-high-risk-files.sh."
    exit 1
fi
