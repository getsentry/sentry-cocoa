#!/bin/bash
set -euox pipefail

# When enableThreadSanitizer is enabled and ThreadSanitizer finds an issue,
# the logs only show failing tests, but don't highlight the threading issues.
# Therefore we print a hint to find the threading issues. Profiler doesn't
# run when it detects TSAN is present, so we skip those tests.
set -o pipefail && NSUnbufferedIO=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO xcodebuild \
    -workspace Sentry.xcworkspace \
    -scheme Sentry \
    -configuration Test \
    -enableThreadSanitizer YES \
    -destination "platform=iOS Simulator,OS=latest,name=iPhone 16" \
    -skip-testing:"SentryProfilerTests" \
    test 2>&1 |
    tee thread-sanitizer.log |
    xcbeautify --report junit

testStatus=$?

if [ $testStatus -eq 0 ]; then
    echo "ThreadSanitizer didn't find problems."
else
    echo "ThreadSanitizer found problems or one of the tests failed. Search for \"ThreadSanitizer\" in the thread-sanitizer.log artifact for more details."
fi
