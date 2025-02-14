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
SENTRY_SCHEME="Sentry"

ENV_SIGNED_BINARY="NSUnbufferedIO=YES"
ENV_UNSIGNED_BINARY="CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO"
ENVIRONMENT_VARIABLES="$ENV_UNSIGNED_BINARY"

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
    echo "  -S|--signed <bool>              Whether or not to allow codesigning the build product (default: false)"
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
            SENTRY_SCHEME="$2"
            shift 2
            ;;
        -S|--signed)
            ENVIRONMENT_VARIABLES="$ENV_SIGNED_BINARY"
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
"watchOS")
    DESTINATION="platform=watchOS Simulator,OS=$OS,name=Apple Watch"
    ;;
*)
    echo "Xcode Test: Can't find destination for platform '$PLATFORM'"
    exit 1
    ;;
esac

if [ -n "$CONFIGURATION_OVERRIDE" ]; then
    CONFIGURATION="$CONFIGURATION_OVERRIDE"
elif [ "$COMMAND" == "build" ]; then
    CONFIGURATION="Debug"
elif [ "$COMMAND" == "analyze" ]; then
    CONFIGURATION="Release"
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
    RUN_ANALYZE=false
    RUN_BUILD=true
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=false
    RUN_TEST_WITH_TSAN=false
    ;;
"build-for-testing")
    RUN_ANALYZE=false
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=true
    RUN_TEST_WITHOUT_BUILDING=false
    RUN_TEST_WITH_TSAN=false
    ;;
"test-without-building")
    RUN_ANALYZE=false
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=true
    RUN_TEST_WITH_TSAN=false
    ;;
"analyze")
    RUN_ANALYZE=true
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=false
    RUN_TEST_WITH_TSAN=false
    ;;
"tsan")
    RUN_ANALYZE=false
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=false
    RUN_TEST_WITHOUT_BUILDING=false
    RUN_TEST_WITH_TSAN=true
    ;;
*)
    RUN_ANALYZE=false
    RUN_BUILD=false
    RUN_BUILD_FOR_TESTING=true
    RUN_TEST_WITHOUT_BUILDING=true
    RUN_TEST_WITH_TSAN=false
    ;;
esac

if [ "${CI-false}" == true ]; then
    RUBY_ENV_ARGS=""
else
    RUBY_ENV_ARGS="rbenv exec bundle exec"
fi

if [ $RUN_BUILD == true ]; then
    set -o pipefail && xcodebuild \
        "$ENVIRONMENT_VARIABLES" \
        -workspace Sentry.xcworkspace \
        -scheme "$SENTRY_SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -quiet \
        build \
        | $RUBY_ENV_ARGS xcpretty
elif [ $RUN_ANALYZE == true ]; then
    rm -rf analyzer
    set -o pipefail && "$ENVIRONMENT_VARIABLES" xcodebuild \
        -workspace Sentry.xcworkspace \
        CLANG_ANALYZER_OUTPUT=html \
        CLANG_ANALYZER_OUTPUT_DIR=analyzer \
        CODE_SIGNING_ALLOWED="NO" \
        -scheme "$SENTRY_SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        analyze \
        2>&1 \
        | $RUBY_ENV_ARGS xcpretty -t \
        && [[ -z $(find analyzer -name "*.html") ]]
        xcbeautify
elif [ $RUN_TEST_WITH_TSAN == true ]; then
    # When enableThreadSanitizer is enabled and ThreadSanitizer finds an issue,
    # the logs only show failing tests, but don't highlight the threading issues.
    # Therefore we print a hint to find the threading issues. Profiler doesn't
    # run when it detects TSAN is present, so we skip those tests.
    set -o pipefail && "$ENVIRONMENT_VARIABLES" xcodebuild \
        -workspace Sentry.xcworkspace \
        -scheme "$SENTRY_SCHEME" \
        -configuration "$CONFIGURATION" \
        -enableThreadSanitizer YES \
        -destination "$DESTINATION" \
        -skip-testing:"SentryProfilerTests" \
        test \
        | tee thread-sanitizer.log \
        tee raw-test-output.log |

    testStatus=$?

    if [ "$testStatus" -eq 0 ]; then
        echo "ThreadSanitizer didn't find problems."
    else
        echo "ThreadSanitizer found problems or one of the tests failed. Search for \"ThreadSanitizer\" in the thread-sanitizer.log artifact for more details."
    fi
else
    if [ $RUN_BUILD_FOR_TESTING == true ]; then
        set -o pipefail && "$ENVIRONMENT_VARIABLES" xcodebuild \
            -workspace Sentry.xcworkspace \
            -scheme "$SENTRY_SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "$DESTINATION" \
            build-for-testing \
            | $RUBY_ENV_ARGS xcpretty
    fi

    if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
        set -o pipefail && "$ENVIRONMENT_VARIABLES" xcodebuild \
            -workspace Sentry.xcworkspace \
            -scheme "$SENTRY_SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "$DESTINATION" \
            test-without-building \
            | tee raw-test-output.log \
            | $RUBY_ENV_ARGS xcpretty -t \
            && slather coverage --configuration "$CONFIGURATION"
    fi
fi
