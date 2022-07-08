#!/bin/bash
set -euo pipefail

# To update the sha run shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m)
EXPECTED="54a41f19ca05866605bf05da4d27f4df34143701c2d70a82221d52fc7c895ebc  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. If your changes are intended please update the sha in ./scripts/no-changes-in-high-risk-files.sh."
    exit 1
fi
