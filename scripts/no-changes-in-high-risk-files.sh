#!/bin/bash
set -euo pipefail

# To update the sha run shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m)
EXPECTED="819d5ca5e3db2ac23c859b14c149b7f0754d3ae88bea1dba92c18f49a81da0e1  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. If your changes are intended please update the sha in ./scripts/no-changes-in-high-risk-files.sh to $ACTUAL."
    exit 1
fi
