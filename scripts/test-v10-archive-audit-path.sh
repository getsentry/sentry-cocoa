#!/bin/bash
# Test that the packaging workflow audits the build output it actually produced. A previous
# lookup searched Xcode's default DerivedData directory, but our packaging scripts write to
# XCFrameworkBuildPath/DerivedData. It also assumed archive intermediates existed, whereas
# Mac Catalyst uses a regular build. Packaging could succeed and then fail before the audit ran.
#
# Run the actual workflow audit command against small archive and Catalyst directory fixtures,
# with no default Xcode build directory. A stand-in for the object verifier checks that it gets
# the correct build root, and that its failures fail the workflow step too. This tests the
# workflow wiring without rebuilding the SDK; it does not replace the real object audit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

WORK_DIR=""
usage() {
    log_info "Usage: $0 [-w|--work-dir <path>]"
    log_info "  -w, --work-dir <path>  Retain fixtures in this directory (default: temporary directory)"
    exit 1
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--work-dir) WORK_DIR="$2"; shift 2 ;;
        *) usage ;;
    esac
done
if [[ -z "$WORK_DIR" ]]; then
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' EXIT
fi
mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

# Execute the actual workflow step, not a duplicate of its path-selection logic.
yq -r '.jobs."package-v10".steps[] | select(.name == "Check packaged SDK build output") | .run' \
    "$SCRIPT_DIR/../.github/workflows/build-v10.yml" > "$WORK_DIR/audit-step.sh"
if [[ ! -s "$WORK_DIR/audit-step.sh" ]]; then
    log_error "Missing packaged SDK build-output check"
    exit 1
fi

# Check the real archive producer too: a hand-created directory fixture alone would hide
# an archive command that still writes to Xcode's default DerivedData directory.
producer="$WORK_DIR/producer"
mkdir -p "$producer/bin"

# The generated stub expands these variables when executed, not while being written.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    'derived_data=""' 'while [[ $# -gt 0 ]]; do' \
    '  if [[ "$1" == -derivedDataPath ]]; then derived_data="$2"; shift 2; else shift; fi' \
    'done' '[[ "$derived_data" == XCFrameworkBuildPath/DerivedData ]] || { echo "Archive producer did not set the audit build root" >&2; exit 1; }' \
    'mkdir -p "$derived_data/Build/Products/ReleaseV10-maccatalyst/Sentry.framework"' 'echo "producer compiler evidence"' 'echo "** ARCHIVE SUCCEEDED **"' 'exit "${PRODUCER_EXIT_STATUS:-0}"' > "$producer/bin/xcodebuild"

# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'while IFS= read -r line; do printf "%s\\n" "$line"; done' > "$producer/bin/xcbeautify"

chmod +x "$producer/bin/xcodebuild" "$producer/bin/xcbeautify"
(
    cd "$producer"
    PATH="$producer/bin:$PATH" "$SCRIPT_DIR/build-xcframework-slice.sh" \
        --sdk iphoneos --scheme SentryV10 --configuration-suffix V10 --product-name Sentry
)

grep -Fq 'producer compiler evidence' "$producer/XCFrameworkBuildPath/raw-build-output.log"
grep -Fq '** ARCHIVE SUCCEEDED **' "$producer/XCFrameworkBuildPath/raw-build-output.log"
if (
    cd "$producer"
    PATH="$producer/bin:$PATH" PRODUCER_EXIT_STATUS=42 "$SCRIPT_DIR/build-xcframework-slice.sh" \
        --sdk iphoneos --scheme SentryV10 --configuration-suffix V10 --product-name Sentry
); then
    log_error "Archive producer ignored xcodebuild failure"
    exit 1
fi

(
    cd "$producer"
    PATH="$producer/bin:$PATH" "$SCRIPT_DIR/build-xcframework-slice.sh" \
        --sdk maccatalyst --scheme SentryV10 --configuration-suffix V10 --product-name Sentry
)
grep -Fq 'producer compiler evidence' "$producer/XCFrameworkBuildPath/raw-build-output.log"
log_info "Passed archive/Catalyst producer build root, raw log and failure propagation"

for layout in maccatalyst archive; do
    fixture="$WORK_DIR/$layout"
    mkdir -p "$fixture/scripts" "$fixture/home" "$fixture/XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex"
    if [[ "$layout" == archive ]]; then
        mkdir -p "$fixture/XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/SentryV10/IntermediateBuildFilesPath"
        expected_root="XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/SentryV10/IntermediateBuildFilesPath"
    else
        expected_root="XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex"
    fi

    printf '%s\n' 'producer compiler evidence' '** BUILD SUCCEEDED **' > "$fixture/XCFrameworkBuildPath/raw-build-output.log"

    # Stub only the expensive object audit; require the workflow to pass the producer's
    # retained compiler tree. Catalyst deliberately has no ArchiveIntermediates.
    printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
        "[[ \"\$#\" == 4 && \"\$1\" == --build-path && \"\$2\" == $expected_root ]]" \
        "[[ \"\$3\" == --build-log && \"\$4\" == XCFrameworkBuildPath/raw-build-output.log ]]" \
        "[[ -d \"\$2\" && -s \"\$4\" ]]" 'touch audit-invoked' "exit \"\${AUDIT_EXIT_STATUS:-0}\"" \
        > "$fixture/scripts/verify-v10-sentrycrash-objects.sh"
    chmod +x "$fixture/scripts/verify-v10-sentrycrash-objects.sh"
    (
        cd "$fixture"
        HOME="$fixture/home" bash -e "$WORK_DIR/audit-step.sh"
        [[ -f audit-invoked ]]

        # An audit failure must still fail the workflow step.
        if HOME="$fixture/home" AUDIT_EXIT_STATUS=42 bash -e "$WORK_DIR/audit-step.sh"; then
            log_error "Workflow ignored the object audit failure"
            exit 1
        fi
    )
    log_info "Passed $layout workflow audit path and failure propagation"
done

# SDK builds must audit the whole DerivedData tree: the same log also records
# package aggregates in Build/Products, not just SentryV10's Objects-normal folder.
sdk_fixture="$WORK_DIR/sdk-workflow"
sdk_root="$sdk_fixture/home/Library/Developer/Xcode/DerivedData/SDK"
mkdir -p "$sdk_root/Build/Intermediates.noindex/Sentry.build/DebugV10/SentryV10.build/Objects-normal" "$sdk_fixture/scripts" "$sdk_fixture/bin"
yq -r '.jobs."build-v10".steps[] | select(.name == "Build V10") | .run' \
    "$SCRIPT_DIR/../.github/workflows/build-v10.yml" | \
    jq -Rs -r 'gsub("\\$\\{\\{ matrix.make-target \\}\\}"; "build-macos-v10")' > "$sdk_fixture/build-step.sh"

# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    '[[ "$#" == 1 && "$1" == build-macos-v10 ]]' \
    'grep -Fxq "ENABLE_CODE_COVERAGE = NO" "$XCODE_XCCONFIG_FILE"' \
    'touch build-invoked' > "$sdk_fixture/bin/make"

chmod +x "$sdk_fixture/bin/make"
(
    cd "$sdk_fixture"
    PATH="$sdk_fixture/bin:$PATH" RUNNER_TEMP="$sdk_fixture" bash -e build-step.sh
    [[ -f build-invoked ]]
)

printf '%s\n' '** BUILD SUCCEEDED **' > "$sdk_fixture/raw-build-output.log"

yq -r '.jobs."build-v10".steps[] | select(.name == "Verify recorder source exclusion") | .run' \
    "$SCRIPT_DIR/../.github/workflows/build-v10.yml" | \
    jq -Rs -r 'gsub("\\$\\{\\{ matrix.objects-configuration \\}\\}"; "DebugV10")' > "$sdk_fixture/audit-step.sh"

printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    "[[ \"\$#\" == 4 && \"\$1\" == --build-path && \"\$2\" == '$sdk_root' && \"\$3\" == --build-log && \"\$4\" == raw-build-output.log ]]" \
    'touch audit-invoked' "exit \"\${AUDIT_EXIT_STATUS:-0}\"" > "$sdk_fixture/scripts/verify-v10-sentrycrash-objects.sh"

chmod +x "$sdk_fixture/scripts/verify-v10-sentrycrash-objects.sh"
(
    cd "$sdk_fixture"
    HOME="$sdk_fixture/home" bash -e audit-step.sh

    [[ -f audit-invoked ]]

    if HOME="$sdk_fixture/home" AUDIT_EXIT_STATUS=42 bash -e audit-step.sh; then
        log_error 'SDK workflow ignored the object audit failure'
        exit 1
    fi
)

log_info 'Passed SDK workflow compiler-output root, raw log and failure propagation'

# Run the real orchestrator with cheap producer/auditor stand-ins. Every slice must
# be audited before another producer clears its outputs, and before assembly.
orchestrator="$WORK_DIR/orchestrator"
mkdir -p "$orchestrator/scripts"
cp "$SCRIPT_DIR/build-xcframework-v10.sh" "$SCRIPT_DIR/ci-utils.sh" "$orchestrator/scripts/"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    'sdk=""; while [[ $# -gt 0 ]]; do if [[ "$1" == --sdk ]]; then sdk="$2"; fi; shift 2; done' \
    '[[ ! -e pending-audit ]]' 'echo "$sdk" > pending-audit' \
    'rm -rf XCFrameworkBuildPath/DerivedData' \
    'root=XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex' \
    'if [[ "$sdk" != maccatalyst ]]; then root+=/ArchiveIntermediates/SentryV10/IntermediateBuildFilesPath; fi' \
    'mkdir -p "$root"' 'echo "$sdk" > XCFrameworkBuildPath/raw-build-output.log' \
    > "$orchestrator/scripts/build-xcframework-slice.sh"

# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    '[[ "$#" == 4 && "$1" == --build-path && -d "$2" && "$3" == --build-log ]]' \
    'cmp pending-audit "$4"' '[[ "${AUDIT_EXIT_STATUS:-0}" == 0 ]] || exit "$AUDIT_EXIT_STATUS"' \
    'cat pending-audit >> audited-slices' 'rm pending-audit' \
    > "$orchestrator/scripts/verify-v10-sentrycrash-objects.sh"

printf '%s\n' '#!/bin/bash' 'set -euo pipefail' '[[ ! -e pending-audit ]]' 'touch assembled' \
    > "$orchestrator/scripts/assemble-xcframework.sh"

chmod +x "$orchestrator/scripts/"*.sh
(
    cd "$orchestrator"

    scripts/build-xcframework-v10.sh --sdks macosx,maccatalyst

    [[ "$(wc -l < audited-slices | tr -d ' ')" == 2 && -f assembled ]]
    rm assembled

    if AUDIT_EXIT_STATUS=42 scripts/build-xcframework-v10.sh --sdks macosx,maccatalyst; then
        log_error "V10 packager ignored a slice audit failure"
        exit 1
    fi

    [[ ! -e assembled ]]
)

log_info 'Passed per-slice audit ordering and failure propagation'
