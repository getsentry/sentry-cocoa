#!/bin/bash

# When enableThreadSanitizer is enabled and ThreadSanitizer finds an issue, 
# the logs only show failing tests, but don't highlight the threading issues.
# Therefore we print a hint to find the threading issues.

env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -configuration Test -enableThreadSanitizer YES \
    -destination "platform=iOS Simulator,OS=latest,name=iPhone 11" \
    # The test works when having thread sanitizer not enabled, we have no clue why it fails, and threading issues will be caught
    # even when it is disabled.
    -skip-testing:"Sentry/SentrySessionTestsSwift/testInitWithJson_IfJsonContainsWrongValues_SessionIsNil" \
    test | tee thread-sanitizer.log | xcpretty -t

testStatus=$?

if [ $testStatus -eq 0 ]; then
    echo "ThreadSanitizer didn't find problems."
    exit 0
else
    echo "ThreadSanitizer found problems or one of the tests failed. Search for \"ThreadSanitizer\" in the thread-sanitizer.log artifact for more details."
    exit 1
fi
