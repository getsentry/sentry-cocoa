#!/bin/bash
set -euo pipefail

# To update the sha run the command in ACTUAL and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m ./Sources/Sentry/SentryNetworkTracker.m ./Sources/Sentry/SentryUIViewControllerSwizzling.m ./Sources/Sentry/SentryNSDataSwizzling.m ./Sources/Sentry/SentrySubClassFinder.m ./Sources/Sentry/SentryCoreDataSwizzling.m ./Sources/Sentry/SentrySwizzleWrapper.m ./Sources/Sentry/include/SentrySwizzle.h ./Sources/Sentry/SentrySwizzle.m)
EXPECTED="819d5ca5e3db2ac23c859b14c149b7f0754d3ae88bea1dba92c18f49a81da0e1  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m
57056426d77fd1cc27e72bdcea4bbf617dd8c1e82eecf003df8f0e348aae90ab  ./Sources/Sentry/SentryNetworkTracker.m
98870d3e56cfffaac042d59f8d20eb9fbbe70e573e54e1016a9b60170052c9e3  ./Sources/Sentry/SentryUIViewControllerSwizzling.m
e95e62ec7363984f20c78643bb7d992a41a740f97e1befb71525ac34caf88b37  ./Sources/Sentry/SentryNSDataSwizzling.m
64c6a25fc657ce60f54b46a8ad48a713a2cfae80e5f137a6a1e20ea08dac2d6c  ./Sources/Sentry/SentrySubClassFinder.m
59db11da66e6ac0058526be0be08b57cdccd3727033e85164a631b205e972134  ./Sources/Sentry/SentryCoreDataSwizzling.m
4d9b9526e7e64baaeb60ae0080d31c1e683218e4c947fb07ce4a755c14b96a35  ./Sources/Sentry/SentrySwizzleWrapper.m
b1c642450170358cab39b4cc6cd546f27c41b12eacb90c3ad93f87733d46e56c  ./Sources/Sentry/include/SentrySwizzle.h
f97128c823f92d1c2ec37e5e3b2914f7488a94043af6a8344e348f1a14425f47  ./Sources/Sentry/SentrySwizzle.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. You might want to test your changes by using 'make test-alamofire' and 'make test-homekit' to ensure the changes are safe to run on third party projects."
    echo "If your changes are intended and everything is running properly, please update the sha in ./scripts/no-changes-in-high-risk-files.sh to: "
    echo "$ACTUAL"
    exit 1
fi
