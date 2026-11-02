#!/usr/bin/env bash
# Generate matching V9 API dumps, then report public source-API differences.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

OUTPUT_DIR=""
GENERATION_ARGS=("$@")

usage() {
    log_info "Usage: $0 --output-dir <path> [options]"
    log_info "  -o, --output-dir <path>      New report directory outside the checkout (required)"
    log_info "  -p, --source-packages <path> Seed builds from an existing Xcode SourcePackages cache"
    log_info "  -k, --keep-builds            Retain temporary sources and build products (default: false)"
    log_info "  -h, --help                   Show this help"
    log_info "Uses the selected Xcode, V9 Release, arm64 iOS Simulator; no simulator is booted."
    log_info "API differences are informational; build/extraction errors return nonzero."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir|-p|--source-packages)
            if [[ $# -lt 2 || -z "$2" ]]; then
                log_error "Missing value for $1"
                exit 2
            fi
            if [[ "$1" == "-o" || "$1" == "--output-dir" ]]; then
                OUTPUT_DIR="$2"
            fi
            shift 2 ;;
        -k|--keep-builds) shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

# Both mode guarantees matching inputs by taking one working-tree snapshot.
# Generation failures propagate unchanged; only API differences become warnings.
"$SCRIPT_DIR/generate-api-dump.sh" --build-system both "${GENERATION_ARGS[@]}"

begin_group "Report API parity"
status=0
python3 "$SCRIPT_DIR/compare-public-api.py" \
    --baseline "$OUTPUT_DIR/xcode-public.json" --candidate "$OUTPUT_DIR/spm-public.json" \
    --output-dir "$OUTPUT_DIR/report" || status=$?
case "$status" in
    0) log_info "The compared source APIs match" ;;
    1) log_warning "Xcode and SwiftPM expose different source APIs; see the informational report" ;;
    *) log_error "API comparison failed (exit $status)"; exit "$status" ;;
esac
log_info "Report: $OUTPUT_DIR/report/summary.md"
end_group
