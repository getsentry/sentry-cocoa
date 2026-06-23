#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

XCFRAMEWORK_PATH=""
SIGN=false

usage() {
    log_notice "Usage: $0 --xcframework <path> [--sign]"
    log_notice "  --xcframework <path>    Path to the .xcframework directory (required)"
    log_notice "  --sign                  Codesign with the Sentry certificate"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --xcframework)
            if [ $# -lt 2 ]; then
                usage
            fi
            XCFRAMEWORK_PATH="$2"
            shift 2
            ;;
        --sign)
            SIGN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            ;;
    esac
done

if [ -z "$XCFRAMEWORK_PATH" ]; then
    log_error "Error: --xcframework is required"
    usage
fi

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    log_error "XCFramework path does not exist: $XCFRAMEWORK_PATH"
    exit 1
fi

sentry_certificate="Apple Distribution: GetSentry LLC (97JCY7859U)"

log_info "Compress XCFramework:"
log_info "  Path:      $XCFRAMEWORK_PATH"
log_info "  Signing:   $SIGN"

if [[ "$SIGN" == true ]]; then
    begin_group "Signing $XCFRAMEWORK_PATH"
    log_info "Signing with certificate: $sentry_certificate"
    codesign --sign "$sentry_certificate" --timestamp --options runtime --deep --force "$XCFRAMEWORK_PATH"
    codesign --verify --deep --strict --verbose=2 "$XCFRAMEWORK_PATH"
    end_group
fi

begin_group "Compressing $XCFRAMEWORK_PATH"
ditto -c -k -X --rsrc --keepParent "$XCFRAMEWORK_PATH" "$XCFRAMEWORK_PATH.zip"
log_info "Created $XCFRAMEWORK_PATH.zip"
end_group
