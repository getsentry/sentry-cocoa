#!/bin/bash
set -euo pipefail

# To update the sha run shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m)
EXPECTED="9d30dbb25eb69dae7d7fa0fed9f440b9f5c19b1250a029f9387682ec645f97e7  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. If your changes are intended please update the sha in ./scripts/no-changes-in-high-risk-files.sh."
    exit 1
fi
