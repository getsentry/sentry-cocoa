#!/bin/bash
set -euox pipefail

# This is a helper script for GitHub Actions Matrix.
# If we would specify the destinations in the GitHub Actions
# Matrix, the name of the job would include the destination, which would
# be, for example, platform=tvOS Simulator,OS=latest,name=Apple TV 4K.
# To fix this, we specify a readable platform in the matrix and then call
# this script to map the platform to the destination.

PLATFORM="${1}"
OS=${2:-latest}
XCODE="${3}"
REF_NAME="${4}"
DESTINATION=""
CONFIGURATION=""
RETRY_FLAGS=""

case $PLATFORM in

    "macOS")
        DESTINATION="platform=macOS"
        ;;

    "Catalyst")
        DESTINATION="platform=macOS,variant=Mac Catalyst"
        ;;

    "iOS")
        DESTINATION="platform=iOS Simulator,OS=$OS,name=iPhone 8"
        ;;

    "tvOS")
        DESTINATION="platform=tvOS Simulator,OS=$OS,name=Apple TV 4K"
        ;;
    
    *)
        echo "Xcode Test: Can't find destination for platform '$PLATFORM'"; 
        exit 1;
        ;;
esac

echo "REF_NAME: $REF_NAME"

case $REF_NAME in
    "master")
        CONFIGURATION="TestCI"
        ;;
    
    *)
        CONFIGURATION="Test"
        ;;
esac

echo "CONFIGURATION: $CONFIGURATION"

if [ $XCODE == "13.2.1" ]; then
    env NSUnbufferedIO=YES xcodebuild -retry-tests-on-failure -test-iterations 3 -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        test | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}
elif [ $PLATFORM == "iOS" -a $OS == "12.4" ]; then
    echo "Skipping some tests that fail on iOS 12.4."
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -skip-testing:"SentryTests/SentryNetworkTrackerIntegrationTests/testGetRequest_SpanCreatedAndTraceHeaderAdded" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfAddingBreadcrumbs" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfTransactions" \
        test | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}
elif [ $XCODE == "12.5.1" ]; then
    # There are some known flaky tests on Xcode 12.5.1 runs. Run the suite normally without them, then try the flaky tests up to 3 times. We do this in a bash for loop because xcodebuild didn't get the -retry-tests-on-failure option until version 13.
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -skip-testing:"SentryTests/SentrySessionTrackerTests" \
        test | tee raw-test-output.log | xcpretty -t

    nonflaky_test_status=${PIPESTATUS[0]}

    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -only-testing:"SentryTests/SentrySessionTrackerTests" \
        test | tee raw-test-output.log | xcpretty -t
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        exit $nonflaky_test_status
    else
        for {1..2}; do
            bash -c 'env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
                -scheme Sentry -configuration $CONFIGURATION \
                GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
                -only-testing:"SentryTests/SentrySessionTrackerTests" \
                test-without-building | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}'
            flaky_test_status=$?
            if [ $flaky_test_status -eq 0 ]; then
                exit $nonflaky_test_status
            fi
        done
        exit $nonflaky_test_status
    fi
else
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        test | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}
fi
