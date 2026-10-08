#!/bin/bash
# Exercise the real slice producer and V10 packager with command stand-ins.
# Keep failure propagation and audit-before-replacement/assembly coverage here;
# real CI builds validate compiler outputs, archive layouts and workflow wiring.
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
        -w|--work-dir) [[ $# -ge 2 ]] || usage; WORK_DIR="$2"; shift 2 ;;
        *) usage ;;
    esac
done
if [[ -z "$WORK_DIR" ]]; then
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' EXIT
fi
mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

expect_failure() {
    local name="$1" status=0
    shift
    "$@" > "$WORK_DIR/$name.log" 2>&1 || status=$?
    if [[ "$status" != 42 ]]; then
        cat "$WORK_DIR/$name.log" >&2
        log_error "$name: expected exit 42, got $status"
        exit 1
    fi
    log_info "Passed $name"
}

# A successful formatter must not hide xcodebuild's failure in either producer branch.
producer="$WORK_DIR/producer"
mkdir -p "$producer/bin"
printf '#!/bin/bash\nexit 42\n' > "$producer/bin/xcodebuild"
printf '#!/bin/bash\ncat\n' > "$producer/bin/xcbeautify"
chmod +x "$producer/bin/xcodebuild" "$producer/bin/xcbeautify"
(
    cd "$producer"
    for sdk in iphoneos maccatalyst; do
        expect_failure "$sdk-build-failure" env PATH="$producer/bin:$PATH" \
            "$SCRIPT_DIR/build-xcframework-slice.sh" --sdk "$sdk" --scheme SentryV10
    done
)

# Every slice must be audited before another producer replaces its outputs or assembly runs.
orchestrator="$WORK_DIR/orchestrator"
mkdir -p "$orchestrator/scripts"
cp "$SCRIPT_DIR/build-xcframework-v10.sh" "$SCRIPT_DIR/ci-utils.sh" "$orchestrator/scripts/"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    'sdk=""; while [[ $# -gt 0 ]]; do if [[ "$1" == --sdk ]]; then sdk="$2"; fi; shift 2; done' \
    '[[ ! -e pending-audit ]] || { touch ordering-failed; exit 1; }' \
    '[[ "${PRODUCER_EXIT_STATUS:-0}" == 0 ]] || exit "$PRODUCER_EXIT_STATUS"' \
    'echo "$sdk" > pending-audit' 'rm -rf XCFrameworkBuildPath/DerivedData' \
    'root=XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex' \
    'if [[ "$sdk" != maccatalyst ]]; then root+=/ArchiveIntermediates/SentryV10/IntermediateBuildFilesPath; fi' \
    'mkdir -p "$root"' 'echo "$sdk" > XCFrameworkBuildPath/raw-build-output.log' \
    > "$orchestrator/scripts/build-xcframework-slice.sh"

# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    '[[ "$#" == 4 && "$1" == --build-path && -d "$2" && "$3" == --build-log ]] || exit 1' \
    'cmp pending-audit "$4"' '[[ "${AUDIT_EXIT_STATUS:-0}" == 0 ]] || exit "$AUDIT_EXIT_STATUS"' \
    'cat pending-audit >> audited-slices' 'rm pending-audit' \
    > "$orchestrator/scripts/verify-v10-sentrycrash-objects.sh"

printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    '[[ ! -e pending-audit ]] || { touch ordering-failed; exit 1; }' 'touch assembled' \
    > "$orchestrator/scripts/assemble-xcframework.sh"
chmod +x "$orchestrator/scripts/"*.sh
(
    cd "$orchestrator"
    scripts/build-xcframework-v10.sh --sdks macosx,maccatalyst
    [[ ! -e ordering-failed && -f assembled && "$(< audited-slices)" == $'macosx\nmaccatalyst' ]] || {
        log_error 'Slices were not audited before replacement/assembly'; exit 1;
    }
    log_info 'Passed per-slice audit ordering'
    rm assembled audited-slices

    expect_failure orchestrator-build-failure env PRODUCER_EXIT_STATUS=42 \
        scripts/build-xcframework-v10.sh --sdks macosx,maccatalyst
    [[ ! -e assembled && ! -e pending-audit && ! -e audited-slices ]] || {
        log_error 'Packaging continued after a producer failure'; exit 1;
    }

    expect_failure orchestrator-audit-failure env AUDIT_EXIT_STATUS=42 \
        scripts/build-xcframework-v10.sh --sdks macosx,maccatalyst
    [[ ! -e assembled && ! -e audited-slices ]] || {
        log_error 'Packaging continued after an audit failure'; exit 1;
    }
)
