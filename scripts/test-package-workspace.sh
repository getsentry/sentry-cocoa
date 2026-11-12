#!/bin/bash
# Xcode expands these build settings, not the shell.
# shellcheck disable=SC2016
set -euo pipefail

# shellcheck source=./ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR=""

usage() {
    log_info "Usage: $(basename "$0") [--work-dir|-w PATH]"
    log_info "  -w, --work-dir PATH  New directory for fixtures and logs (default: temporary directory)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--work-dir) [[ $# -ge 2 ]] || usage; WORK_DIR="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [[ -n "$WORK_DIR" ]]; then
    [[ ! -e "$WORK_DIR" ]] || { log_error "Work directory already exists: $WORK_DIR"; exit 1; }
    mkdir -p "$WORK_DIR"
else
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sentry-package-tests.XXXXXX")"
fi
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
log_info "Evidence: $WORK_DIR"

mkdir -p "$WORK_DIR/tools" "$WORK_DIR/Tests/Configuration" "$WORK_DIR/results"
cp "$REPO_ROOT/Tests/Configuration/SwiftPM.xcconfig" "$WORK_DIR/Tests/Configuration/"
cat > "$WORK_DIR/tools/xcodebuild" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$@" > "$RECORD"
exit "${BUILD_STATUS:-0}"
SH
cat > "$WORK_DIR/tools/xcbeautify" <<'SH'
#!/bin/bash
cat
SH
chmod +x "$WORK_DIR/tools/"*
export PATH="$WORK_DIR/tools:$PATH"
export RUNNER_TEMP="$WORK_DIR/results"
cd "$WORK_DIR"

assert_arg() {
    grep -Fxq -- "$1" "$RECORD" || { log_error "Missing argument: $1 ($RECORD)"; exit 1; }
}

# Exercise the real runner against replaceable command boundaries, without an
# Xcode project or workspace in the fixture. Both phases must select the same graph.
for sdk_v10 in 0 1; do
    export SDK_V10="$sdk_v10"
    for configuration in Test TestCI; do
        for command in build-for-testing test-without-building; do
            export RECORD="$WORK_DIR/$sdk_v10-$configuration-$command.args"
            bash "$REPO_ROOT/scripts/sentry-xcodebuild.sh" --package-tests \
                --platform macOS --command "$command" --configuration "$configuration" \
                > "$RECORD.log" 2>&1
            assert_arg -workspace
            assert_arg .
            assert_arg SentrySPM
            plan=SentrySPM_Base
            [[ "$sdk_v10" = 1 ]] && plan=SentrySPM_Base_v10
            assert_arg "$plan"
            assert_arg "$configuration"
            assert_arg 'platform=macOS'
            assert_arg Tests/Configuration/SwiftPM.xcconfig
            assert_arg "$RUNNER_TEMP/sentry-package-derived-data"
            assert_arg CODE_SIGNING_ALLOWED=NO
            assert_arg -parallel-testing-enabled
            assert_arg "$command"
            if [[ "$configuration" = TestCI ]]; then
                assert_arg 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) SENTRY_TEST_CI'
                assert_arg 'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) DEBUG=1 SENTRY_TEST=1 SENTRY_TEST_CI=1'
            else
                assert_arg 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) SENTRY_TEST'
                assert_arg 'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) DEBUG=1 SENTRY_TEST=1'
            fi
            if [[ "$command" = test-without-building ]]; then
                assert_arg "$RUNNER_TEMP/results.xcresult"
            fi
        done
    done
done

for plan in SentrySPM_Flaky SentrySPM_TestServer SentrySPM_TestServer_v10; do
    export RECORD="$WORK_DIR/$plan.args"
    bash "$REPO_ROOT/scripts/sentry-xcodebuild.sh" --package-tests \
        --platform Catalyst --command test-without-building --configuration TestCI \
        --test-plan "$plan" --result-bundle flaky-results.xcresult \
        --derived-data "$WORK_DIR/custom-derived-data" > "$RECORD.log" 2>&1
    assert_arg "$plan"
    assert_arg 'platform=macOS,variant=Mac Catalyst'
    assert_arg "$RUNNER_TEMP/flaky-results.xcresult"
    assert_arg "$WORK_DIR/custom-derived-data"
done

export RECORD="$WORK_DIR/project.args"
bash "$REPO_ROOT/scripts/sentry-xcodebuild.sh" --platform macOS \
    --command build-for-testing --configuration TestCI > "$RECORD.log" 2>&1
assert_arg Sentry.xcworkspace
assert_arg Sentry
if grep -Fxq CODE_SIGNING_ALLOWED=NO "$RECORD"; then
    log_error "Package test settings leaked into the project build"
    exit 1
fi

export RECORD="$WORK_DIR/failure.args"
status=0
BUILD_STATUS=65 bash "$REPO_ROOT/scripts/sentry-xcodebuild.sh" --package-tests \
    --platform macOS --configuration TestCI --command test > "$RECORD.log" 2>&1 || status=$?
[[ "$status" = 65 ]] || { log_error "Build failure was not propagated: $status"; exit 1; }
log_info "All package-workspace runner checks passed"
