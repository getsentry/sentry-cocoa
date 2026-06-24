#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

XCFRAMEWORK_PATH=""

usage() {
    log_notice "Usage: $0 --xcframework <path>"
    log_notice "  --xcframework <path>    XCFramework bundle to validate (required)"
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

"$SCRIPT_DIR/validate-xcframework-format.sh" --xcframework "$XCFRAMEWORK_PATH"
"$SCRIPT_DIR/validate-xcframework-architectures.sh" --xcframework "$XCFRAMEWORK_PATH"
"$SCRIPT_DIR/validate-xcframework-symbols.sh" --xcframework "$XCFRAMEWORK_PATH"
"$SCRIPT_DIR/validate-xcframework-info-plist.sh" --xcframework "$XCFRAMEWORK_PATH"
