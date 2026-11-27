#!/bin/bash
#
# Copies the SentryObjC public headers with every SDK_V10 gate resolved.
#
# The public headers gate V10-only and V9-only API with SDK_V10. Packaged headers must match the
# V10 binary, because consumers such as bindings generators do not define SDK_V10 themselves.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

HEADERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/Sources/SentryObjC/Public"
OUTPUT_DIR=""

usage() {
    log_info "Usage: $0 --output-dir <path> [options]"
    log_info "  -o, --output-dir <path>   Directory for the resolved headers; replaced if it exists (required)"
    log_info "  -H, --headers <path>      Source headers (default: Sources/SentryObjC/Public)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ $# -lt 2 && "$1" != -h && "$1" != --help ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case "$1" in
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -H|--headers)    HEADERS_DIR="$2"; shift 2 ;;
        -h|--help)       usage ;;
        *)               log_error "Unknown argument: $1"; usage ;;
    esac
done

if [[ -z "$OUTPUT_DIR" || "$OUTPUT_DIR" == / ]]; then
    log_error "--output-dir must be a non-root directory"
    usage
fi
if [[ ! -d "$HEADERS_DIR" ]]; then
    log_error "Public headers directory not found at $HEADERS_DIR"
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
for header in "$HEADERS_DIR"/*.h; do
    # unifdef exits with 1 when it changed the file and with 2 on errors.
    unifdef -DSDK_V10=1 -o "$OUTPUT_DIR/$(basename "$header")" "$header" || [ $? -eq 1 ]
done
log_info "Resolved V10 SentryObjC headers at $OUTPUT_DIR"
