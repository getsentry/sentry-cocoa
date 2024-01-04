#!/bin/bash
set -euo pipefail

# To update the sha run the command in ACTUAL and copy the result in EXPECTED.

ACTUAL=$(shasum -a 256 ./Sources/Sentry/SentryNSURLSessionTaskSearch.m ./Sources/Sentry/SentryNetworkTracker.m ./Sources/Sentry/SentryUIViewControllerSwizzling.m ./Sources/Sentry/SentryNSDataSwizzling.m ./Sources/Sentry/SentrySubClassFinder.m ./Sources/Sentry/SentryCoreDataSwizzling.m ./Sources/Sentry/SentrySwizzleWrapper.m ./Sources/Sentry/include/SentrySwizzle.h ./Sources/Sentry/SentrySwizzle.m)
EXPECTED="894bf150506dde6ad9b1dbb7439a2abe3960d702fc0c21775b33ed7dee1b43d5  ./Sources/Sentry/SentryNSURLSessionTaskSearch.m
8ee3071726d3af38a96361d3066b8be12ef1f74f774d6292ee0acc240d9e53a4  ./Sources/Sentry/SentryNetworkTracker.m
fba389d928c7237f532f27a3e6afc9ab31f4ddcee4faaf32756974d9bbb44014  ./Sources/Sentry/SentryUIViewControllerSwizzling.m
9d64737c0bdb8be3f3dac151b6bdfef8dcee4c2cde9b8be02b31db7d4ff5b460  ./Sources/Sentry/SentryNSDataSwizzling.m
15144d9891dcce34fe1fbc61d67c9cc6c858f914dd863b9311ef33637d501498  ./Sources/Sentry/SentrySubClassFinder.m
7c4578dc1a015a6d574172a28791c79d53349e529391f8db11d3f375786b9f5a  ./Sources/Sentry/SentryCoreDataSwizzling.m
f2ba2c472c074bf19aec141dc5b7f1a7f6f0cc9aeccdb8299d0aee3bf90f8125  ./Sources/Sentry/SentrySwizzleWrapper.m
b1b9778dcdeea02377ed7ec6e2ea413c6ea23d72b142ef47c5aebb6824ba63e0  ./Sources/Sentry/include/SentrySwizzle.h
4e85f76b275c1765593f178a8b13fa5249d3740fcefcbd9bb3722d38165542b1  ./Sources/Sentry/SentrySwizzle.m"

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "No changes in high risk files."
    exit 0
else
    echo "Changes in high risk files. You might want to test your changes by using 'make test-alamofire' and 'make test-homekit' to ensure the changes are safe to run on third party projects."
    echo "If your changes are intended and everything is running properly, please update the sha in ./scripts/no-changes-in-high-risk-files.sh to: "
    echo "$ACTUAL"
    exit 1
fi
