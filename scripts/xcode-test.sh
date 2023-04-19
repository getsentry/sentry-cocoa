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
REF_NAME="${3-HEAD}"
IS_LOCAL_BUILD="${4:-ci}"
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

env NSUnbufferedIO=YES xcodebuild -workspace Sentry.xcworkspace \
    -scheme Sentry -configuration $CONFIGURATION \
    -destination "$DESTINATION" \
    test | tee raw-test-output.log | $RUBY_ENV_ARGS xcpretty -t && slather coverage --configuration $CONFIGURATION && exit ${PIPESTATUS[0]}
