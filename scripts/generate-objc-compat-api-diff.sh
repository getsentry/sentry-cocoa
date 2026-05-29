#!/bin/bash
set -euo pipefail

# Compute the diff between the SentryObjC public headers and the
# SentryObjCCompat Swift wrapper implementations.
#
# Compares sdk_api_objc.json (what the headers promise) against
# sdk_api_objccompat.json (what the wrappers deliver). Outputs a JSON
# object with two arrays:
#   - only_in_headers: declarations in headers but missing from wrappers
#   - only_in_compat:  declarations in wrappers but missing from headers
#
# The output is committed to the repo. An empty diff means the two are
# in sync. When the diff changes, it signals API drift that needs review.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

HEADERS_JSON=""
COMPAT_JSON=""
OUTPUT=""

usage() {
    log_notice "Usage: $0"
    log_notice "  --headers <path>   sdk_api_objc.json path (required)"
    log_notice "  --compat <path>    sdk_api_objccompat.json path (required)"
    log_notice "  --output <path>    Output diff JSON file path (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --headers) HEADERS_JSON="$2"; shift 2 ;;
        --compat)  COMPAT_JSON="$2";  shift 2 ;;
        --output)  OUTPUT="$2";       shift 2 ;;
        *)         usage ;;
    esac
done

if [ -z "$HEADERS_JSON" ]; then
    log_error "Error: --headers is required"
    usage
fi

if [ -z "$COMPAT_JSON" ]; then
    log_error "Error: --compat is required"
    usage
fi

if [ -z "$OUTPUT" ]; then
    log_error "Error: --output is required"
    usage
fi

if [ ! -f "$HEADERS_JSON" ]; then
    log_error "Headers file not found: $HEADERS_JSON"
    exit 1
fi

if [ ! -f "$COMPAT_JSON" ]; then
    log_error "Compat file not found: $COMPAT_JSON"
    exit 1
fi

log_info "Computing diff between $HEADERS_JSON and $COMPAT_JSON"

jq -n \
    --slurpfile headers "$HEADERS_JSON" \
    --slurpfile compat "$COMPAT_JSON" \
'{
    only_in_headers: ([$headers[0][]] - [$compat[0][]]),
    only_in_compat:  ([$compat[0][]] - [$headers[0][]])
}' > "$OUTPUT"

HEADER_COUNT=$(jq '.only_in_headers | length' "$OUTPUT")
COMPAT_COUNT=$(jq '.only_in_compat | length' "$OUTPUT")

log_info "Diff written to $OUTPUT"
log_info "  Only in headers: $HEADER_COUNT declarations"
log_info "  Only in compat:  $COMPAT_COUNT declarations"
