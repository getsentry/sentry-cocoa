#!/bin/bash
set -euo pipefail

# When enableThreadSanitizer is enabled and ThreadSanitizer finds an issue,
# the logs only show failing tests, but don't highlight the threading issues.
# Therefore we print a hint to find the threading issues.
env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -configuration Test -enableThreadSanitizer YES \
    -destination "platform=iOS Simulator,OS=latest,name=iPhone 14" \
    -skip-testing:"Sentry/SentryThreadInspectorTests/testStacktraceHasFrames_forEveryThread" \
    -skip-testing:"Sentry/SentryThreadInspectorTests/testGetCurrentThreadWithStackTrack_TooManyThreads" \
    -skip-testing:"SentryTests/SentryNSDataTrackerTests/testWriteAtomically_CheckTransaction_FilterOut_nonProcessFrames" \
    -skip-testing:"SentryTests/SentryFileManagerTests/testDefaultMaxEnvelopesConcurrent" \
    -skip-testing:"SentryTests/SentryCrashBinaryImageCacheTests/testAddBinaryImageInParallel" \
    -skip-testing:"SentryTests/SentryANRTrackerTests/testMultipleListeners" \
    -skip-testing:"SentryTests/SentryANRTrackerTests/testAppSuspended_NoANR" \
    -skip-testing:"SentryTests.SentryFileIOTrackingIntegrationTests test_DataConsistency_readPath" /
    test | tee thread-sanitizer.log | xcpretty -t

testStatus=$?

if [ $testStatus -eq 0 ]; then
    echo "ThreadSanitizer didn't find problems."
    exit 0
else
    echo "ThreadSanitizer found problems or one of the tests failed. Search for \"ThreadSanitizer\" in the thread-sanitizer.log artifact for more details."
    exit 1
fi
