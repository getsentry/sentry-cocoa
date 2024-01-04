#!/bin/bash
set -euo pipefail

# To update the sha run the command in ACTUAL and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m ./Sources/Sentry/SentryNetworkTracker.m ./Sources/Sentry/SentryUIViewControllerSwizzling.m ./Sources/Sentry/SentryNSDataSwizzling.m ./Sources/Sentry/SentrySubClassFinder.m ./Sources/Sentry/SentryCoreDataSwizzling.m ./Sources/Sentry/SentrySwizzleWrapper.m ./Sources/Sentry/include/SentrySwizzle.h ./Sources/Sentry/SentrySwizzle.m)
EXPECTED="d27b6ef94d0b4cabe592fe2ceeedaf85d2bd91f9b976cc52898cf7f1d9cb12e8  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m
8bbeac08099a0565b074f55734eba3808b121d465d481f7e904b5da4e29295d1  ./Sources/Sentry/SentryNetworkTracker.m
55df7fb3b01775493e7626413e420944cad8fc1988403d283cf6a8750a039ebd  ./Sources/Sentry/SentryUIViewControllerSwizzling.m
435cabc968874a15178fc28cf73f0256a480ae035a5001fb6ebeb545a713c3e6  ./Sources/Sentry/SentryNSDataSwizzling.m
71323c65464c5f959d7f9b26b9ef713feb199864a008b646c515de55d688d13c  ./Sources/Sentry/SentrySubClassFinder.m
aef2e11f9784138a712cb29b05bc98e59ae5aeefbcdc3af2705dc273bd658fb4  ./Sources/Sentry/SentryCoreDataSwizzling.m
0bd685438c4f8405c4fc43bb83cf5ea52a9a811f9b9c56aa1f375c21b13e6eba  ./Sources/Sentry/SentrySwizzleWrapper.m
b1b9778dcdeea02377ed7ec6e2ea413c6ea23d72b142ef47c5aebb6824ba63e0  ./Sources/Sentry/include/SentrySwizzle.h
6752c1cb757816df2817c75650bc85bed8ff906e43eeb3c0b6fed68762ed1aac  ./Sources/Sentry/SentrySwizzle.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. You might want to test your changes by using 'make test-alamofire' and 'make test-homekit' to ensure the changes are safe to run on third party projects."
    echo "If your changes are intended and everything is running properly, please update the sha in ./scripts/no-changes-in-high-risk-files.sh to: "
    echo "$ACTUAL"
    exit 1
fi
