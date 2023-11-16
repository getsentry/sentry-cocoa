#!/bin/bash
set -euo pipefail

# To update the sha run the command in ACTUAL and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m ./Sources/Sentry/SentryNetworkTracker.m ./Sources/Sentry/SentryUIViewControllerSwizzling.m ./Sources/Sentry/SentryNSDataSwizzling.m ./Sources/Sentry/SentrySubClassFinder.m ./Sources/Sentry/SentryCoreDataSwizzling.m ./Sources/Sentry/SentrySwizzleWrapper.m ./Sources/Sentry/include/SentrySwizzle.h ./Sources/Sentry/SentrySwizzle.m)
EXPECTED="819d5ca5e3db2ac23c859b14c149b7f0754d3ae88bea1dba92c18f49a81da0e1  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m
7009e85577eef18d8ab231c39b876f65b25b864b117791e47146917ae81893b0  ./Sources/Sentry/SentryNetworkTracker.m
132a491c706bdb68b47c2e0a14aeaa5c611664f34156565dbfc874b360d6a742  ./Sources/Sentry/SentryUIViewControllerSwizzling.m
e9efd407a713da99d7c2cdb9e30c555d20a8a668ef067b943aafaa024eac5d9e  ./Sources/Sentry/SentryNSDataSwizzling.m
cc3849725bd1733515c71742872bed94ca47d2c115ef9d8c98383eae2e171925  ./Sources/Sentry/SentrySubClassFinder.m
59db11da66e6ac0058526be0be08b57cdccd3727033e85164a631b205e972134  ./Sources/Sentry/SentryCoreDataSwizzling.m
b8da44f7b4d9d0e0ed9d426d7c44d73b6f5de553f48d5c4aa6567ac56c994a27  ./Sources/Sentry/SentrySwizzleWrapper.m
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
