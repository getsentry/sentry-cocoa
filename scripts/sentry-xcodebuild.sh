#!/bin/bash
set -euo pipefail

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
DEVICE=""
CONFIGURATION_OVERRIDE=""
DERIVED_DATA_PATH=""
TEST_SCHEME="Sentry"
TEST_PLAN=""
RESULT_BUNDLE_PATH="results.xcresult"
ONLY_TESTING=""
WORKSPACE="Sentry.xcworkspace"
SDK=""
RAW_DESTINATION=""
OVERRIDE_XCCONFIG=""
XCODEBUILD_ARGS=()
FOR_AGENTS="${FOR_AGENTS:-false}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run xcodebuild commands (build, test, etc.) with the correct destination for CI.

OPTIONS:
    -p, --platform <platform>        Platform (macOS/Catalyst/iOS/tvOS/visionOS/watchOS)
    -o, --os <os>                    OS version (default: latest)
    -c, --command <command>          Command (build/build-for-testing/test-without-building/test)
    -d, --device <device>            Device name (default: platform-specific)
    -C, --configuration <config>     Configuration override
    -D, --derived-data <path>        Derived data path
    -s, --scheme <scheme>            Test scheme (default: Sentry)
    -t, --test-plan <plan>           Test plan name (default: empty)
    --only-testing <tests>           Comma-separated test selectors.
                                      Each selector must be Target, Target/Class, or Target/Class/testMethod.
    -R, --result-bundle <path>       Result bundle path (default: results.xcresult)
    -w, --workspace <path>           Workspace path (default: Sentry.xcworkspace)
    --sdk <sdk>                      SDK override (e.g. iphoneos, watchos)
    --destination <dest>             Raw xcodebuild destination string (bypasses
                                      --platform resolution)
    --xcconfig <path>                Build settings override file
    -- <arguments...>                Forward remaining arguments directly to xcodebuild

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
        --)
            shift
            XCODEBUILD_ARGS=("$@")
            break
            ;;
        --xcconfig)
            OVERRIDE_XCCONFIG="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

if [ -n "$OVERRIDE_XCCONFIG" ] && [ ! -f "$OVERRIDE_XCCONFIG" ]; then
    log_error "--xcconfig file does not exist: $OVERRIDE_XCCONFIG"
    usage
fi

XCCONFIG_ARGS=()
if [ -n "$OVERRIDE_XCCONFIG" ]; then
    XCCONFIG_ARGS=(-xcconfig "$OVERRIDE_XCCONFIG")
fi

if [ -z "$DEVICE" ]; then
    case $PLATFORM in
        "iOS") DEVICE="iPhone 16 Pro" ;;
        "tvOS") DEVICE="Apple TV" ;;
        "visionOS") DEVICE="Apple Vision Pro" ;;
        "watchOS") DEVICE="Apple Watch SE 3 (44mm)" ;;
    esac
fi

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
    # Keep SDK and test targets on the same architecture. Otherwise Xcode can build
    # only arm64e for the SDK while arm64 test utilities import stale arm64 modules.
    DESTINATION="platform=macOS,arch=$(uname -m)"
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
    DESTINATION="platform=tvOS Simulator,OS=$RESOLVED_OS,name=$DEVICE"
    ;;

"visionOS")
    RESOLVED_OS=$(resolve_runtime_version "$PLATFORM" "$OS")
    DESTINATION="platform=visionOS Simulator,OS=$RESOLVED_OS,name=$DEVICE"
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

CONFIGURATION="${CONFIGURATION_OVERRIDE:-Debug}"

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

format_output() {
    if [ "$FOR_AGENTS" = true ]; then
        xcbeautify --quieter --disable-logging
    else
        xcbeautify "$@"
    fi
}

# Package resolution can fail transiently before compilation starts. Retry only
# that failure, bypassing the repository cache without deleting shared caches.
run_build() {
    local output_log="$1"
    shift
    local attempt=1
    local max_attempts=3
    local status
    local retry_args=()

    while true; do
        if NSUnbufferedIO=YES xcodebuild "$@" "${retry_args[@]+${retry_args[@]}}" 2>&1 |
            tee "$output_log" |
            format_output --preserve-unbeautified; then
            return 0
        else
            status=$?
        fi

        if ! grep -Fq 'Could not resolve package dependencies' "$output_log"; then
            return "$status"
        fi

        if [ "$attempt" -ge "$max_attempts" ]; then
            log_error "Package resolution failed after $max_attempts attempts"
            return "$status"
        fi

        cp "$output_log" "${output_log%.log}-attempt-$attempt.log"
        log_info "Package resolution failed (attempt $attempt/$max_attempts). Retrying without the repository cache in $((attempt * 5)) seconds."
        sleep "$((attempt * 5))"
        retry_args=(-disablePackageRepositoryCache)
        attempt=$((attempt + 1))
    done
}

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
    BUILD_ARGS+=("${XCCONFIG_ARGS[@]+${XCCONFIG_ARGS[@]}}")
    BUILD_ARGS+=("${XCODEBUILD_ARGS[@]+${XCODEBUILD_ARGS[@]}}")

    run_build raw-build-output.log "${BUILD_ARGS[@]}" build
fi

# Package tests need explicit metadata so Xcode's native reports include transitive
# SDK sources and executable headers. Export all scheme plans when building so a
# later test-without-building can select Flaky/TestServer without rebuilding.
PACKAGE_TESTS=false
if [[ "$TEST_SCHEME" == SentrySPM && "$COMMAND" != build ]]; then
    PACKAGE_TESTS=true
    if [[ -z "$DERIVED_DATA_PATH" || -z "$PLATFORM" || -z "$CONFIGURATION" ]]; then
        log_error "SentrySPM tests require --derived-data, --platform, and a test configuration"
        exit 1
    fi
    if [ -z "$TEST_PLAN" ]; then
        TEST_PLAN=SentrySPM_Base
        [[ "${SDK_V10:-0}" == 1 ]] && TEST_PLAN=SentrySPM_Base_v10
    fi
fi

TEST_PLAN_ARGS=()
if [ -n "$TEST_PLAN" ]; then
    TEST_PLAN_ARGS+=("-testPlan" "$TEST_PLAN")
fi

ONLY_TESTING_ARGS=()
if [ -n "$ONLY_TESTING" ]; then
    IFS=',' read -ra TEST_ARRAY <<< "$ONLY_TESTING"
    for test in "${TEST_ARRAY[@]}"; do
        if [[ ! "$test" =~ ^[^/[:space:]]+(/[^/[:space:]]+){0,2}$ ]]; then
            log_error "Invalid --only-testing value: $test"
            log_error "Use Target, Target/Class, or Target/Class/testMethod, for example SentryTests/SentrySDKTests."
            exit 1
        fi

        ONLY_TESTING_ARGS+=("-only-testing:$test")
    done
fi

if [ $RUN_BUILD_FOR_TESTING == true ]; then
    log_info "Running xcodebuild build-for-testing"

    BFT_ARGS=(
        -workspace "$WORKSPACE"
        -scheme "$TEST_SCHEME"
        "${ONLY_TESTING_ARGS[@]+${ONLY_TESTING_ARGS[@]}}"
    )
    if [ "$PACKAGE_TESTS" = false ]; then
        BFT_ARGS+=("${TEST_PLAN_ARGS[@]+${TEST_PLAN_ARGS[@]}}")
    fi
    [[ -n "$CONFIGURATION" ]] && BFT_ARGS+=(-configuration "$CONFIGURATION")
    BFT_ARGS+=(-destination "$DESTINATION")
    [[ -n "$DERIVED_DATA_PATH" ]] && BFT_ARGS+=(-derivedDataPath "$DERIVED_DATA_PATH")
    BFT_ARGS+=("${XCCONFIG_ARGS[@]+${XCCONFIG_ARGS[@]}}")
    BFT_ARGS+=("${XCODEBUILD_ARGS[@]+${XCODEBUILD_ARGS[@]}}")

    run_build raw-build-for-testing-output.log "${BFT_ARGS[@]}" build-for-testing

    if [[ "$TEST_SCHEME" == SentrySPM && "${SDK_V10:-0}" == 1 ]]; then
        bash "$(dirname "$0")/build-package-test-fixture.sh" \
            --workspace "$WORKSPACE" \
            --derived-data "$DERIVED_DATA_PATH" \
            --configuration "$CONFIGURATION" \
            --platform "$PLATFORM"
    fi
fi

if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
    log_info "Running xcodebuild test-without-building"

    if [ -d "$RESULT_BUNDLE_PATH" ]; then
        log_info "Removing existing result bundle at $RESULT_BUNDLE_PATH"
        rm -rf "$RESULT_BUNDLE_PATH"
    fi

    if [ "$PACKAGE_TESTS" = true ]; then
        # Drop the incomplete source filter so Xcode uses the binaries' coverage maps.
        # Keep a sibling copy to preserve the original and __TESTROOT__.
        PACKAGE_XCTESTRUN=$(python3 - "$DERIVED_DATA_PATH" "$CONFIGURATION" "$PLATFORM" "$TEST_PLAN" <<'PY'
from pathlib import Path
import plistlib
import sys

derived, configuration, platform, plan = sys.argv[1:]
sdk = {"macOS": "macosx", "Catalyst": "macosx", "iOS": "iphonesimulator",
       "tvOS": "appletvsimulator", "watchOS": "watchsimulator", "visionOS": "xrsimulator"}[platform]
suffix = "" if platform == "macOS" else "-maccatalyst" if platform == "Catalyst" else f"-{sdk}"
paths = [p for p in Path(derived).glob(f"Build/Products/SentrySPM_{plan}_{sdk}*.xctestrun")
         if not p.name.endswith(".coverage.xctestrun")]
if len(paths) != 1:
    sys.exit(f"Expected exactly one .xctestrun for {plan}/{sdk}; build-for-testing first")
original = paths[0]
metadata = plistlib.loads(original.read_bytes())
if not metadata["TestConfigurations"][0]["TestTargets"][0]["TestBundlePath"].startswith(f"__TESTROOT__/{configuration}{suffix}/"):
    sys.exit("Build configuration mismatch; build-for-testing with the same configuration and destination first")
for info in metadata.get("CodeCoverageBuildableInfos", []):
    if any(".xctest/" in path for path in info.get("ProductPaths", [])):
        info.pop("SourceFiles", None)
output = original.with_suffix(".coverage.xctestrun")
output.write_bytes(plistlib.dumps(metadata))
print(output)
PY
        )
        # -xctestrun is an alternative to workspace/scheme/testPlan, not an addition.
        TWB_ARGS=(-xctestrun "$PACKAGE_XCTESTRUN")
    else
        TWB_ARGS=(-workspace "$WORKSPACE" -scheme "$TEST_SCHEME")
        TWB_ARGS+=("${TEST_PLAN_ARGS[@]+${TEST_PLAN_ARGS[@]}}")
        [[ -n "$CONFIGURATION" ]] && TWB_ARGS+=(-configuration "$CONFIGURATION")
        TWB_ARGS+=("${XCCONFIG_ARGS[@]+${XCCONFIG_ARGS[@]}}")
    fi
    TWB_ARGS+=("${ONLY_TESTING_ARGS[@]+${ONLY_TESTING_ARGS[@]}}")
    TWB_ARGS+=(-destination "$DESTINATION")
    TWB_ARGS+=(-resultBundlePath "$RESULT_BUNDLE_PATH")
    # Also binds __DERIVEDDATA__ in the exported metadata (notably ProfileData).
    [[ -n "$DERIVED_DATA_PATH" ]] && TWB_ARGS+=(-derivedDataPath "$DERIVED_DATA_PATH")
    TWB_ARGS+=("${XCODEBUILD_ARGS[@]+${XCODEBUILD_ARGS[@]}}")

    set -o pipefail && NSUnbufferedIO=YES xcodebuild \
        "${TWB_ARGS[@]}" \
        test-without-building 2>&1 |
        tee raw-test-output.log |
        format_output --report junit
fi

log_info "Finished xcodebuild"
