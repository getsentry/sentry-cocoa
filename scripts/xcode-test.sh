#!/bin/bash
set -uox pipefail

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
        DESTINATION="platform=tvOS Simulator,OS=$OS,name=Apple TV"
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

XCODE_MAJOR_VERSION=$(echo $XCODE | sed -E 's/([0-9]*)\.[0-9]*\.?[0-9]+/\1/g')

if [ $PLATFORM == "iOS" -a $OS == "12.4" ]; then
    # Skip some tests that fail on iOS 12.4.
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -skip-testing:"SentryTests/SentryNetworkTrackerIntegrationTests/testGetRequest_SpanCreatedAndTraceHeaderAdded" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfAddingBreadcrumbs" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfTransactions" \
        test | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}
elif [ $XCODE_MAJOR_VERSION == "13" ] || [ $XCODE_MAJOR_VERSION == "14" ]; then
    # We can retry flaky tests that fail with the -retry-tests-on-failure option introduced in Xcode 13.
    env NSUnbufferedIO=YES xcodebuild -retry-tests-on-failure -test-iterations 3 -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        test | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}
elif [ $XCODE_MAJOR_VERSION == "12" ]; then
    # To retry flaky tests in Xcode <13, Run the suite normally without them, then run the suite with just the known flaky tests up to 3 times in a bash loop because xcodebuild didn't get the -retry-tests-on-failure option until version 13.
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -skip-testing:"SentryTests/SentrySessionTrackerTests" \
        test | tee raw-test-output.log | xcpretty -t
    nonflaky_test_status=${PIPESTATUS[0]}

    # try the flaky tests once. if they pass, exit with the combined status of flaky and nonflaky tests.
    # if they fail, retry them twice more.

    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -only-testing:"SentryTests/SentrySessionTrackerTests" \
        test | tee raw-test-output.log | xcpretty -t
    flaky_test_status=${PIPESTATUS[0]}
    if [ $flaky_test_status -eq 0 ]; then
        exit $nonflaky_test_status
    else
        for i in {1..2}; do
            bash -c "env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
                -scheme Sentry -configuration $CONFIGURATION \
                GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination '$DESTINATION' \
                -only-testing:'SentryTests/SentrySessionTrackerTests' \
                test-without-building | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}"
            flaky_test_status=$?
            if [ $flaky_test_status -eq 0 ]; then
                exit $nonflaky_test_status
            fi
        done

        # combine flaky/nonflaky statuses for the exit status of this script so that if either have failed, the script will fail
        all_test_status=$nonflaky_test_status
        let 'all_test_status|=flaky_test_status'
        exit $all_test_status
    fi
else
    # The branches above are exhaustive at the time they were written. This will help us catch unexpected deviations with future changes.
    exit 1
fi
