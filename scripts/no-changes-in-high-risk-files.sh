#!/bin/bash
set -euox pipefail

# To update the sha run the command in ACTUAL and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m ./Sources/Sentry/SentryNetworkTracker.m ./Sources/Sentry/SentryUIViewControllerSwizzling.m ./Sources/Sentry/SentryNSDataSwizzling.m ./Sources/Sentry/SentrySubClassFinder.m ./Sources/Sentry/SentryCoreDataSwizzling.m ./Sources/Sentry/SentrySwizzleWrapper.m ./Sources/Sentry/include/SentrySwizzle.h ./Sources/Sentry/SentrySwizzle.m)
EXPECTED="819d5ca5e3db2ac23c859b14c149b7f0754d3ae88bea1dba92c18f49a81da0e1  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m
797f1e4f1f4d0986770c749c6614243417373d3858044a0aa6e16bd4a52533ed  ./Sources/Sentry/SentryNetworkTracker.m
92185b9fc9eb59842a3b3ecffe420e29621ea1c444dc80135e0e3eea397a9f46  ./Sources/Sentry/SentryUIViewControllerSwizzling.m
e95e62ec7363984f20c78643bb7d992a41a740f97e1befb71525ac34caf88b37  ./Sources/Sentry/SentryNSDataSwizzling.m
0a685b5ee8d660958b79b663df7e65ca558d976c8be8ad44d3d2ff11bc8f8e62  ./Sources/Sentry/SentrySubClassFinder.m
59db11da66e6ac0058526be0be08b57cdccd3727033e85164a631b205e972134  ./Sources/Sentry/SentryCoreDataSwizzling.m
71a493066cb209b674cdc434db74d45caf3afa3e5560cc2a28fccd64b0556bf0  ./Sources/Sentry/SentrySwizzleWrapper.m
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
