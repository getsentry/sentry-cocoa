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
IS_LOCAL_BUILD="${4:-ci}"
COMMAND="${5:-test}"
DEVICE=${6:-iPhone 14}
SANITIZER="${7:-none}"

# get an arbitrary list of test identifiers to skip at the end of regular arguments
for i in {1..7}; do
    shift
done
SKIPPED_TESTS=""
for z in $@; do
    SKIPPED_TESTS+="-skip-test:$z "
done

DESTINATION=""
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

CONFIGURATION=""
case $REF_NAME in
"main")
    CONFIGURATION="TestCI"
    ;;

*)
    CONFIGURATION="Test"
    ;;
esac

case $IS_LOCAL_BUILD in
"ci")
    RUBY_ENV_ARGS=""
    ;;
*)
    RUBY_ENV_ARGS="rbenv exec bundle exec"
    ;;
esac

case $COMMAND in
"build-for-testing")
    RUN_BUILD_FOR_TESTING=true
    RUN_TEST_WITHOUT_BUILDING=false
    ;;
"test-without-building")
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=true
    ;;
*)
    RUN_BUILD_FOR_TESTING=true
    RUN_TEST_WITHOUT_BUILDING=true
    ;;
esac

case $SANITIZER in
"TSAN")
    SANITIZER_ARGUMENT="-enableThreadSanitizer YES"
    ;;
"ASAN")
    SANITIZER_ARGUMENT="-enableAddressSanitizer YES"
    ;;
"UBSAN")
    SANITIZER_ARGUMENT="-enableUndefinedBehaviorSanitizer YES"
    ;;
*)
    SANITIZER_ARGUMENT=""
    ;;
esac

if [ $RUN_BUILD_FOR_TESTING == true ]; then
    # build everything for testing
    env NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme Sentry \
        -configuration $CONFIGURATION \
        -destination "$DESTINATION" -quiet \
        $SANITIZER_ARGUMENT \
        build-for-testing
fi

if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
    # run the tests
    env NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme Sentry \
        -configuration $CONFIGURATION \
        -destination "$DESTINATION" \
        $SANITIZER_ARGUMENT \
        $SKIPPED_TESTS \
        test-without-building |
        tee raw-test-output.log |
        $RUBY_ENV_ARGS xcpretty -t &&
        slather coverage --configuration $CONFIGURATION &&
        exit ${PIPESTATUS[0]}
fi
