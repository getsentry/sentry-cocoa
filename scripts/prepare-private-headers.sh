#!/bin/bash
# Prepare the private headers shipped in Sentry.framework/PrivateHeaders.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SOURCE_DIR="$SCRIPT_DIR/../Sources/Sentry/include"
OUTPUT_DIR=""

# Hybrid SDKs import these from the framework. Keep the list in sync with the Private headers of
# the Xcode-built Sentry and Sentry-Dynamic release artifacts; removing one is a breaking change.
PRIVATE_HEADERS=(
    SentryAsynchronousOperation.h
    SentryBreadcrumb+Private.h
    SentryCrashReportConverter.h
    SentryDateUtils.h
    SentryFormatter.h
    SentryInternalSerializable.h
    SentryLogC.h
    SentryNSDataUtils.h
    SentryRequestOperation.h
    SentrySDK+Private.h
    SentryStoredCrashReportProcessor.h
    SentrySwift.h
    SentrySwizzle.h
    SentryUser+Private.h
)

usage() {
    log_info "Usage: $0"
    log_info "  -o, --output-dir <path>  Directory to fill with the private headers (required)"
    log_info "Use the same SDK_V10 environment setting as the framework's public headers."
    exit 1
}

while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || usage
    case $1 in
        -o|--output-dir) OUTPUT_DIR="$2" ;;
        *) usage ;;
    esac
    shift 2
done

[[ -n "$OUTPUT_DIR" ]] || usage

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
for header in "${PRIVATE_HEADERS[@]}"; do
    source_header="$SOURCE_DIR/$header"
    if [ ! -f "$source_header" ]; then
        log_error "Missing private header: $source_header"
        exit 1
    fi
    if [ "${SDK_V10:-0}" = 1 ]; then
        # Match the public headers and SentryV10.xcconfig's COPY_HEADERS_RUN_UNIFDEF.
        xcrun unifdef -DSDK_V10=1 -o "$OUTPUT_DIR/$header" "$source_header" || [ $? -eq 1 ]
    else
        cp "$source_header" "$OUTPUT_DIR/"
    fi
done
log_info "Prepared ${#PRIVATE_HEADERS[@]} private headers: $OUTPUT_DIR"
