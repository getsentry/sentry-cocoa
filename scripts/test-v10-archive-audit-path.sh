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
yq -r '.jobs."package-v10".steps[] | select(.name == "Verify packaged SDK compile provenance") | .run' \
    "$SCRIPT_DIR/../.github/workflows/build-v10.yml" > "$WORK_DIR/audit-step.sh"
if [[ ! -s "$WORK_DIR/audit-step.sh" ]]; then
    log_error "Missing packaged SDK provenance step"
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
    'mkdir -p "$derived_data"' > "$producer/bin/xcodebuild"

# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'while IFS= read -r line; do printf "%s\\n" "$line"; done' > "$producer/bin/xcbeautify"

chmod +x "$producer/bin/xcodebuild" "$producer/bin/xcbeautify"
(
    cd "$producer"
    PATH="$producer/bin:$PATH" "$SCRIPT_DIR/build-xcframework-slice.sh" \
        --sdk iphoneos --scheme SentryV10 --configuration-suffix V10 --product-name Sentry
)

log_info "Passed actual archive producer DerivedData argument"

for layout in maccatalyst archive; do
    fixture="$WORK_DIR/$layout"
    mkdir -p "$fixture/scripts" "$fixture/home" "$fixture/XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex"
    if [[ "$layout" == archive ]]; then
        mkdir -p "$fixture/XCFrameworkBuildPath/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/SentryV10"
    fi

    # Stub only the expensive object audit; require the workflow to pass the producer's
    # complete DerivedData tree. Catalyst deliberately has no ArchiveIntermediates.
    printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
        "[[ \"\$#\" == 2 && \"\$1\" == --build-path && \"\$2\" == XCFrameworkBuildPath/DerivedData ]]" \
        "[[ -d \"\$2\" ]]" 'touch audit-invoked' "exit \"\${AUDIT_EXIT_STATUS:-0}\"" \
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
