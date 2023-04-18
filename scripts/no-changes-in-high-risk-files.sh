#!/bin/bash
set -euo pipefail

# To update the sha run the command in ACTUAL and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m ./Sources/Sentry/SentryNetworkTracker.m ./Sources/Sentry/SentryUIViewControllerSwizzling.m ./Sources/Sentry/SentryNSDataSwizzling.m ./Sources/Sentry/SentrySubClassFinder.m ./Sources/Sentry/SentryCoreDataSwizzling.m ./Sources/Sentry/SentrySwizzleWrapper.m ./Sources/Sentry/Include/SentrySwizzle.h ./Sources/Sentry/SentrySwizzle.m)
EXPECTED="819d5ca5e3db2ac23c859b14c149b7f0754d3ae88bea1dba92c18f49a81da0e1  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m
58d5414b4f0a4c821b20fc1a16f88bda3116401e905b7bc1d18af828be75e431  ./Sources/Sentry/SentryNetworkTracker.m
52cb473dcc8d13c0d4f6cd1429c3fc6e8588521660b714f4a2edb4eaf1401e9f  ./Sources/Sentry/SentryUIViewControllerSwizzling.m
e95e62ec7363984f20c78643bb7d992a41a740f97e1befb71525ac34caf88b37  ./Sources/Sentry/SentryNSDataSwizzling.m
9ad05dd8dd29788cba994736fdcd3bbde59a94e32612640d11f4f9c38ad6610e  ./Sources/Sentry/SentrySubClassFinder.m
13c3030d8c1fb145760d51837773c35127c777fce1d4dbb9009d53d0fcc5dce8  ./Sources/Sentry/SentryCoreDataSwizzling.m
e41c853a75dcc31a2783ec513acc8c7af8a67033ab8585c80b525f63dd26b506  ./Sources/Sentry/SentrySwizzleWrapper.m
b1c642450170358cab39b4cc6cd546f27c41b12eacb90c3ad93f87733d46e56c  ./Sources/Sentry/Include/SentrySwizzle.h
f97128c823f92d1c2ec37e5e3b2914f7488a94043af6a8344e348f1a14425f47  ./Sources/Sentry/SentrySwizzle.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. You might want to test your changes by using `make test-alamofire` and `make test-homekit` to ensure the changes are safe to run on third party projects."
    echo "If your changes are intended and everything is running properly, please update the sha in ./scripts/no-changes-in-high-risk-files.sh to: "
    echo "$ACTUAL"
    exit 1
fi
