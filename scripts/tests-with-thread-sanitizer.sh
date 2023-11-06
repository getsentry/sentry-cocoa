#!/bin/bash
set -euox pipefail

# When enableThreadSanitizer is enabled and ThreadSanitizer finds an issue,
# the logs only show failing tests, but don't highlight the threading issues.
# Therefore we print a hint to find the threading issues. Profiler doesn't
# run when it detects TSAN is present, so we skip those tests.
env NSUnbufferedIO=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -configuration Test -enableThreadSanitizer YES \
    -destination "platform=iOS Simulator,OS=latest,name=iPhone 14" \
    -skip-testing:"SentryProfilerTests" \
    test | tee thread-sanitizer.log | xcpretty -t

testStatus=$?

if [ $testStatus -eq 0 ]; then
    echo "ThreadSanitizer didn't find problems."
else
    echo "ThreadSanitizer found problems or one of the tests failed. Search for \"ThreadSanitizer\" in the thread-sanitizer.log artifact for more details."
fi
