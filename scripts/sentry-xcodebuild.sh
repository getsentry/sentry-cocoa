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
DEVICE="iPhone 16 Pro"
CONFIGURATION_OVERRIDE=""
DERIVED_DATA_PATH=""
TEST_SCHEME="Sentry"
TEST_PLAN=""
RESULT_BUNDLE_PATH="results.xcresult"
ONLY_TESTING=""
WORKSPACE="Sentry.xcworkspace"
SDK=""
RAW_DESTINATION=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run xcodebuild commands (build, test, etc.) with the correct destination for CI.

OPTIONS:
    -p, --platform <platform>        Platform (macOS/Catalyst/iOS/tvOS/visionOS/watchOS)
    -o, --os <os>                    OS version (default: latest)
    -r, --ref <ref>                  Reference name (default: HEAD)
    -c, --command <command>          Command (build/build-for-testing/test-without-building/test)
    -d, --device <device>            Device name (default: iPhone 16 Pro)
    -C, --configuration <config>     Configuration override
    -D, --derived-data <path>        Derived data path
    -s, --scheme <scheme>            Test scheme (default: Sentry)
    -t, --test-plan <plan>           Test plan name (default: empty)
    --only-testing <tests>           Comma-separated test selectors.
                                      Each selector must be Target/Class or Target/Class/testMethod.
    -R, --result-bundle <path>       Result bundle path (default: results.xcresult)
    -w, --workspace <path>           Workspace path (default: Sentry.xcworkspace)
    --sdk <sdk>                      SDK override (e.g. iphoneos, watchos)
    --destination <dest>             Raw xcodebuild destination string (bypasses
                                      --platform resolution)

EXAMPLES:
    $(basename "$0") -p iOS -c test
    $(basename "$0") -p macOS -c build -C Release
    $(basename "$0") -p iOS -c test --only-testing SentryTests/SentrySDKTests
    $(basename "$0") -w . -s SentrySPM --sdk iphoneos --destination 'generic/platform=iphoneos' -c build

EOF
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
        --only-testing)
            # Note: No short option to avoid confusion with -o (used by --os)
            ONLY_TESTING="$2"
            shift 2
            ;;
        -R|--result-bundle)
            RESULT_BUNDLE_PATH="$2"
            shift 2
            ;;
        -w|--workspace)
            WORKSPACE="$2"
            shift 2
            ;;
        --sdk)
            SDK="$2"
            shift 2
            ;;
        --destination)
            RAW_DESTINATION="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Resolve the actual simulator runtime version from simctl.
# The display version (e.g., "26.3") may differ from the build version (e.g., "26.3.1")
# and xcodebuild requires the build version in the destination.
resolve_runtime_version() {
    local platform="$1"
    local os="$2"
    local resolved
    resolved=$(xcrun simctl list runtimes -v | \
        grep -E "$platform $os " | sed -n 's/.*(\([0-9.]*\) -.*/\1/p' | head -n1)
    if [ -n "$resolved" ]; then
        echo "$resolved"
    else
        echo "$os"
    fi
}

if [ -n "$RAW_DESTINATION" ]; then
    DESTINATION="$RAW_DESTINATION"
else

case $PLATFORM in

"macOS")
    DESTINATION="platform=macOS"
    ;;

"Catalyst")
    DESTINATION="platform=macOS,variant=Mac Catalyst"
    ;;

"iOS")
    RESOLVED_OS=$(resolve_runtime_version "$PLATFORM" "$OS")
    DESTINATION="platform=iOS Simulator,OS=$RESOLVED_OS,name=$DEVICE"
    ;;

"tvOS")
    RESOLVED_OS=$(resolve_runtime_version "$PLATFORM" "$OS")
    DESTINATION="platform=tvOS Simulator,OS=$RESOLVED_OS,name=Apple TV"
    ;;

"visionOS")
    RESOLVED_OS=$(resolve_runtime_version "$PLATFORM" "$OS")
    DESTINATION="platform=visionOS Simulator,OS=$RESOLVED_OS,name=Apple Vision Pro"
    ;;

"watchOS")
    RESOLVED_OS=$(resolve_runtime_version "$PLATFORM" "$OS")
    DESTINATION="platform=watchOS Simulator,OS=$RESOLVED_OS,name=$DEVICE"
    ;;

*)
    log_error "Xcode Test: Can't find destination for platform '$PLATFORM'"
    exit 1
    ;;
esac

fi # RAW_DESTINATION check

if [ -n "$CONFIGURATION_OVERRIDE" ]; then
    CONFIGURATION="$CONFIGURATION_OVERRIDE"
elif [ -n "$RAW_DESTINATION" ]; then
    CONFIGURATION=""
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
    log_info "Running xcodebuild build"

    BUILD_ARGS=(
        -workspace "$WORKSPACE"
        -scheme "$TEST_SCHEME"
    )
    [[ -n "$SDK" ]] && BUILD_ARGS+=(-sdk "$SDK")
    [[ -n "$CONFIGURATION" ]] && BUILD_ARGS+=(-configuration "$CONFIGURATION")
    BUILD_ARGS+=(-destination "$DESTINATION")
    [[ -n "$DERIVED_DATA_PATH" ]] && BUILD_ARGS+=(-derivedDataPath "$DERIVED_DATA_PATH")

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        "${BUILD_ARGS[@]}" \
        build 2>&1 |
        tee raw-build-output.log |
        xcbeautify --preserve-unbeautified
fi

TEST_PLAN_ARGS=()
if [ -n "$TEST_PLAN" ]; then
    TEST_PLAN_ARGS+=("-testPlan" "$TEST_PLAN")
fi

ONLY_TESTING_ARGS=()
if [ -n "$ONLY_TESTING" ]; then
    IFS=',' read -ra TEST_ARRAY <<< "$ONLY_TESTING"
    for test in "${TEST_ARRAY[@]}"; do
        if [[ ! "$test" =~ ^[^/[:space:]]+/[^/[:space:]]+(/[^/[:space:]]+)?$ ]]; then
            log_error "Invalid --only-testing value: $test"
            log_error "Use Target/Class or Target/Class/testMethod, for example SentryTests/SentrySDKTests."
            exit 1
        fi

        ONLY_TESTING_ARGS+=("-only-testing:$test")
    done
fi

if [ $RUN_BUILD_FOR_TESTING == true ]; then
    # When no test plan is provided, we skip the -testPlan argument so xcodebuild uses the default test plan
    log_info "Running xcodebuild build-for-testing"

    BFT_ARGS=(
        -workspace "$WORKSPACE"
        -scheme "$TEST_SCHEME"
        "${TEST_PLAN_ARGS[@]+${TEST_PLAN_ARGS[@]}}"
        "${ONLY_TESTING_ARGS[@]+${ONLY_TESTING_ARGS[@]}}"
    )
    [[ -n "$CONFIGURATION" ]] && BFT_ARGS+=(-configuration "$CONFIGURATION")
    BFT_ARGS+=(-destination "$DESTINATION")

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        "${BFT_ARGS[@]}" \
        build-for-testing 2>&1 |
        tee raw-build-for-testing-output.log |
        xcbeautify --preserve-unbeautified
fi

if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
    # When no test plan is provided, we skip the -testPlan argument so xcodebuild uses the default test plan
    log_info "Running xcodebuild test-without-building"

    if [ -d "$RESULT_BUNDLE_PATH" ]; then
        log_info "Removing existing result bundle at $RESULT_BUNDLE_PATH"
        rm -rf "$RESULT_BUNDLE_PATH"
    fi

    TWB_ARGS=(
        -workspace "$WORKSPACE"
        -scheme "$TEST_SCHEME"
        "${TEST_PLAN_ARGS[@]+${TEST_PLAN_ARGS[@]}}"
        "${ONLY_TESTING_ARGS[@]+${ONLY_TESTING_ARGS[@]}}"
    )
    [[ -n "$CONFIGURATION" ]] && TWB_ARGS+=(-configuration "$CONFIGURATION")
    TWB_ARGS+=(-destination "$DESTINATION")
    TWB_ARGS+=(-resultBundlePath "$RESULT_BUNDLE_PATH")

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        "${TWB_ARGS[@]}" \
        test-without-building 2>&1 |
        tee raw-test-output.log |
        xcbeautify --report junit
fi

log_info "Finished xcodebuild"
