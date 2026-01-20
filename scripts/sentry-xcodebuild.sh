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
REF_NAME="HEAD"
COMMAND="test"
DEVICE="iPhone 14 Pro"
CONFIGURATION_OVERRIDE=""
DERIVED_DATA_PATH=""
TEST_SCHEME="Sentry"
TEST_PLAN=""
RESULT_BUNDLE_PATH="results.xcresult"
SPM_PROJECT="false"

usage() {
    echo "Usage: $0"
    echo "  -p|--platform <platform>        Platform (macOS/Catalyst/iOS/tvOS)"
    echo "  -o|--os <os>                    OS version (default: latest)"
    echo "  -r|--ref <ref>                  Reference name (default: HEAD)"
    echo "  -c|--command <command>          Command (build/build-for-testing/test-without-building/test)"
    echo "  -d|--device <device>            Device name (default: iPhone 14 Pro)"
    echo "  -C|--configuration <config>     Configuration override"
    echo "  -D|--derived-data <path>        Derived data path"
    echo "  -s|--scheme <scheme>            Test scheme (default: Sentry)"
    echo "  -t|--test-plan <plan>           Test plan name (default: empty)"
    echo "  -R|--result-bundle <path>       Result bundle path (default: results.xcresult)"
    echo "  -S|--spm-project <bool>         Use SPM project (default: false)"
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
        -t|--test-plan)
            TEST_PLAN="$2"
            shift 2
            ;;
        -R|--result-bundle)
            RESULT_BUNDLE_PATH="$2"
            shift 2
            ;;
        -S|--spm-project)
            SPM_PROJECT="$2"
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

"visionOS")
    DESTINATION="platform=visionOS Simulator,OS=$OS,name=Apple Vision Pro"
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
    log_notice "Running xcodebuild build"
    
    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme "$TEST_SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build 2>&1 |
        tee raw-build-output.log |
        xcbeautify --preserve-unbeautified
fi

TEST_PLAN_ARGS=()
if [ -n "$TEST_PLAN" ]; then
    TEST_PLAN_ARGS+=("-testPlan" "$TEST_PLAN")
fi

# Build xcodebuild arguments based on project type
XCODEBUILD_ARGS=()
if [ "$SPM_PROJECT" != "true" ]; then
    XCODEBUILD_ARGS+=("-workspace" "Sentry.xcworkspace")
    XCODEBUILD_ARGS+=("-configuration" "$CONFIGURATION")
fi
XCODEBUILD_ARGS+=("-scheme" "$TEST_SCHEME")
XCODEBUILD_ARGS+=("${TEST_PLAN_ARGS[@]+${TEST_PLAN_ARGS[@]}}")
XCODEBUILD_ARGS+=("-destination" "$DESTINATION")

# SPM packages don't have scheme files with codeCoverageEnabled settings,
# so we need to explicitly enable code coverage for SPM projects
if [ "$SPM_PROJECT" == "true" ]; then
    XCODEBUILD_ARGS+=("-enableCodeCoverage" "YES")
fi

if [ $RUN_BUILD_FOR_TESTING == true ]; then
    # When no test plan is provided, we skip the -testPlan argument so xcodebuild uses the default test plan
    log_notice "Running xcodebuild build-for-testing"

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        "${XCODEBUILD_ARGS[@]}" \
        build-for-testing 2>&1 |
        tee raw-build-for-testing-output.log |
        xcbeautify --preserve-unbeautified
fi

if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
    # When no test plan is provided, we skip the -testPlan argument so xcodebuild uses the default test plan
    log_notice "Running xcodebuild test-without-building"

    if [ -d "$RESULT_BUNDLE_PATH" ]; then
        log_notice "Removing existing result bundle at $RESULT_BUNDLE_PATH"
        rm -rf "$RESULT_BUNDLE_PATH"
    fi

    XCODEBUILD_ARGS+=("-resultBundlePath" "$RESULT_BUNDLE_PATH")

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        "${XCODEBUILD_ARGS[@]}" \
        test-without-building 2>&1 |
        tee raw-test-output.log |
        xcbeautify --report junit
fi

log_notice "Finished xcodebuild"
