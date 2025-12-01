#!/bin/bash
set -euxo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

# This is a helper script for GitHub Actions Matrix.
# If we would specify the destinations in the GitHub Actions
# Matrix, the name of the job would include the destination, which would
# be, for example, platform=tvOS Simulator,OS=latest,name=Apple TV 4K.
# To fix this, we specify a readable platform in the matrix and then call
# this script to map the platform to the destination.

# Parse named arguments
PLATFORM=""
OS="latest"
COMMAND="test"
DEVICE="iPhone 14 Pro"
TEST_SCHEME="Sentry"
RESULT_BUNDLE_PATH="results.xcresult"

usage() {
    echo "Usage: $0"
    echo "  -p|--platform <platform>        Platform (macOS/Catalyst/iOS/tvOS)"
    echo "  -o|--os <os>                    OS version (default: latest)"
    echo "  -c|--command <command>          Command (build/build-for-testing/test-without-building/test)"
    echo "  -d|--device <device>            Device name (default: iPhone 14 Pro)"
    echo "  -s|--scheme <scheme>            Test scheme (default: Sentry)"
    echo "  -R|--result-bundle <path>       Result bundle path (default: results.xcresult)"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -o|--os)
            OS="$2"
            shift 2
            ;;
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -s|--scheme)
            TEST_SCHEME="$2"
            shift 2
            ;;
        -R|--result-bundle)
            RESULT_BUNDLE_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

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

case $COMMAND in
"build-for-testing")
    RUN_BUILD_FOR_TESTING=true
    RUN_TEST_WITHOUT_BUILDING=false
    ;;
"test-without-building")
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=true
    ;;
esac

if [ "$RUN_BUILD_FOR_TESTING" == true ]; then
    # When no test plan is provided, we skip the -testPlan argument so xcodebuild uses the default test plan
    log_notice "Running xcodebuild build-for-testing"

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -scheme "$TEST_SCHEME" \
        -destination "$DESTINATION" \
        build-for-testing 2>&1 |
        tee raw-build-for-testing-output.log |
        xcbeautify --preserve-unbeautified
fi

if [ "$RUN_TEST_WITHOUT_BUILDING" == true ]; then
    # When no test plan is provided, we skip the -testPlan argument so xcodebuild uses the default test plan
    log_notice "Running xcodebuild test-without-building"

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -scheme "$TEST_SCHEME" \
        -destination "$DESTINATION" \
        -resultBundlePath "$RESULT_BUNDLE_PATH" \
        test-without-building 2>&1 |
        tee raw-test-output.log |
        xcbeautify --report junit
fi

log_notice "Finished xcodebuild"
