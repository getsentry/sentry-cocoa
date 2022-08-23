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

XCODE_MAJOR_VERSION=$(echo $XCODE | sed -E 's/([0-9]*)\.[0-9]*\.[0-9]*/\1/g')


if [ $PLATFORM == "iOS" -a $OS == "12.4" ]; then
    # Skip some tests that fail on iOS 12.4.
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -skip-testing:"SentryTests/SentryNetworkTrackerIntegrationTests/testGetRequest_SpanCreatedAndTraceHeaderAdded" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfAddingBreadcrumbs" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfTransactions" \
        test | tee raw-test-output.log && exit ${PIPESTATUS[0]}
elif [ $XCODE_MAJOR_VERSION == "13" ]; then
    # We can retry flaky tests that fail with the -retry-tests-on-failure option introduced in Xcode 13.
    env NSUnbufferedIO=YES xcodebuild -test-iterations 20 -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        test | tee raw-test-output.log && exit ${PIPESTATUS[0]}
elif [ $XCODE_MAJOR_VERSION == "12" ]; then
    # To retry flaky tests in Xcode <13, Run the suite normally without them, then run the suite with just the known flaky tests up to 3 times in a bash loop because xcodebuild didn't get the -retry-tests-on-failure option until version 13.
    for i in {1..20}; do
        env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
            -scheme Sentry -configuration $CONFIGURATION \
            GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
            test | tee raw-test-output.log && exit ${PIPESTATUS[0]}
    done
else
    # The branches above are exhaustive at the time they were written. This will help us catch unexpected deviations with future changes.
    exit 1
fi
