#!/bin/bash
set -euo pipefail

# To update the sha run the command in ACTUAL and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m ./Sources/Sentry/SentryNetworkTracker.m ./Sources/Sentry/SentryUIViewControllerSwizzling.m ./Sources/Sentry/SentryNSDataSwizzling.m ./Sources/Sentry/SentrySubClassFinder.m ./Sources/Sentry/SentryCoreDataSwizzling.m ./Sources/Sentry/SentrySwizzleWrapper.m ./Sources/Sentry/include/SentrySwizzle.h ./Sources/Sentry/SentrySwizzle.m)
EXPECTED="819d5ca5e3db2ac23c859b14c149b7f0754d3ae88bea1dba92c18f49a81da0e1  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m
545bdd91204ab45d04328dd40233b6fc789b216e1301b5fe2ef23b56db6e3719  ./Sources/Sentry/SentryNetworkTracker.m
128dee523c75c121e9b8b767d84a2a137e5b60498c9f3ba604aad3c935d780d0  ./Sources/Sentry/SentryUIViewControllerSwizzling.m
e95e62ec7363984f20c78643bb7d992a41a740f97e1befb71525ac34caf88b37  ./Sources/Sentry/SentryNSDataSwizzling.m
9ad05dd8dd29788cba994736fdcd3bbde59a94e32612640d11f4f9c38ad6610e  ./Sources/Sentry/SentrySubClassFinder.m
59db11da66e6ac0058526be0be08b57cdccd3727033e85164a631b205e972134  ./Sources/Sentry/SentryCoreDataSwizzling.m
4a041cf2704ca4a8cc1df76bc955781ddd29c3e515aef49898d248d4016e0315  ./Sources/Sentry/SentrySwizzleWrapper.m
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
