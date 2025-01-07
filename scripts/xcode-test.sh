#!/bin/bash
set -euxo pipefail

# This is a helper script for GitHub Actions Matrix.
# If we would specify the destinations in the GitHub Actions
# Matrix, the name of the job would include the destination, which would
# be, for example, platform=tvOS Simulator,OS=latest,name=Apple TV 4K.
# To fix this, we specify a readable platform in the matrix and then call
# this script to map the platform to the destination.

PLATFORM="${1}"
OS=${2:-latest}
REF_NAME="${3-HEAD}"
COMMAND="${4:-test}"
DEVICE=${5:-iPhone 14}
CONFIGURATION_OVERRIDE="${6:-}"
DERIVED_DATA_PATH="${7:-}"

case $PLATFORM in

"macOS")
    DESTINATION="platform=macOS"
    ;;

"Catalyst")
    DESTINATION="platform=macOS,variant=Mac Catalyst"
    ;;

"iOS")
    DESTINATION="platform=iOS Simulator,OS=$OS,name=$DEVICE"
    ;;

"tvOS")
    DESTINATION="platform=tvOS Simulator,OS=$OS,name=Apple TV"
    ;;

*)
    echo "Xcode Test: Can't find destination for platform '$PLATFORM'"
    exit 1
    ;;
esac

if [ -n "$CONFIGURATION_OVERRIDE" ]; then
    CONFIGURATION="$CONFIGURATION_OVERRIDE"
else
    case $REF_NAME in
    "main")
        CONFIGURATION="TestCI"
        ;;

    *)
        CONFIGURATION="Test"
        ;;
    esac
fi

case $COMMAND in
"build")
    RUN_BUILD=true
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=false
    ;;
"build-for-testing")
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=true
    RUN_TEST_WITHOUT_BUILDING=false
    ;;
"test-without-building")
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=true
    ;;
*)
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=true
    RUN_TEST_WITHOUT_BUILDING=true
    ;;
esac

if [ $RUN_BUILD == true ]; then
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme Sentry \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -quiet \
        build 2>&1 |
        tee raw-build-output.log |
        xcbeautify
fi

if [ $RUN_BUILD_FOR_TESTING == true ]; then
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme Sentry \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -quiet \
        build-for-testing 2>&1 |
        tee raw-build-for-testing-output.log |
        xcbeautify
fi

if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme Sentry \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        test-without-building 2>&1 |
        tee raw-test-output.log |
        xcbeautify --quieter --renderer github-actions |
        grep "Error:" || true &&
        slather coverage --configuration "$CONFIGURATION"
fi
