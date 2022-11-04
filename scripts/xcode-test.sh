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
REF_NAME="${3}"
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

if [ $PLATFORM == "iOS" -a $OS == "12.4" ]; then
    # Skip some tests that fail on iOS 12.4.
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfAddingBreadcrumbs" \
        -skip-testing:"SentryTests/SentrySDKTests/testMemoryFootprintOfTransactions" \
        test | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}
else
    env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
        -scheme Sentry -configuration $CONFIGURATION \
        GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" \
        test | tee raw-test-output.log | xcpretty -t && exit ${PIPESTATUS[0]}
fi
