#!/bin/bash
set -euxo pipefail

# This is a helper script for GitHub Actions Matrix.
# If we would specify the destinations in the GitHub Actions
# Matrix, the name of the job would include the destination, which would
# be, for example, platform=tvOS Simulator,OS=latest,name=Apple TV 4K.
# To fix this, we specify a readable platform in the matrix and then call
# this script to map the platform to the destination.

# Parse named arguments
PLATFORM=""
OS="latest"
REF_NAME="HEAD"
COMMAND="test"
DEVICE="iPhone 14"
CONFIGURATION_OVERRIDE=""
DERIVED_DATA_PATH=""
TEST_SCHEME="Sentry"

usage() {
    echo "Usage: $0"
    echo "  -p|--platform <platform>        Platform (macOS/Catalyst/iOS/tvOS)"
    echo "  -o|--os <os>                    OS version (default: latest)"
    echo "  -r|--ref <ref>                  Reference name (default: HEAD)"
    echo "  -c|--command <command>          Command (build/build-for-testing/test-without-building/test)"
    echo "  -d|--device <device>            Device name (default: iPhone 14)"
    echo "  -C|--configuration <config>     Configuration override"
    echo "  -D|--derived-data <path>        Derived data path"
    echo "  -s|--scheme <scheme>            Test scheme (default: Sentry)"
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
        -r|--ref)
            REF_NAME="$2"
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
        -C|--configuration)
            CONFIGURATION_OVERRIDE="$2"
            shift 2
            ;;
        -D|--derived-data)
            DERIVED_DATA_PATH="$2"
            shift 2
            ;;
        -s|--scheme)
            TEST_SCHEME="$2"
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
        -scheme "$TEST_SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -quiet \
        build 2>&1 |
        tee raw-build-output.log |
        xcbeautify --report junit
fi

if [ $RUN_BUILD_FOR_TESTING == true ]; then
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme "$TEST_SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -quiet \
        build-for-testing 2>&1 |
        tee raw-build-for-testing-output.log |
        xcbeautify --report junit
fi

if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme "$TEST_SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        test-without-building 2>&1 |
        tee raw-test-output.log |
        xcbeautify  --report junit &&
        slather coverage --configuration "$CONFIGURATION" --scheme "$TEST_SCHEME"
fi
