#!/bin/bash
#
# Validates that every Swift module interface in an XCFramework records the SDK version
# with -user-module-version, so consumers can use `#if canImport(Sentry, _version: ...)`.
# See https://docs.swift.org/latest/documentation/diagnostics/module-version-missing/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./tools.sh disable=SC1091
source "$SCRIPT_DIR/tools.sh"
# shellcheck source=./xcframework-utils.sh disable=SC1091
source "$SCRIPT_DIR/xcframework-utils.sh"

XCFRAMEWORK_PATH=""
EXPECTED_VERSION=""

usage() {
    log_info "Usage: $0 --xcframework <path> [--expected-version <version>]"
    log_info "  --xcframework <path>          XCFramework bundle to validate (required)"
    log_info "  --expected-version <version>  Expected version (default: MARKETING_VERSION from Versioning.xcconfig)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --xcframework|--expected-version)
            if [ $# -lt 2 ]; then
                usage
            fi
            if [ "$1" = --xcframework ]; then
                XCFRAMEWORK_PATH="$2"
            else
                EXPECTED_VERSION="$2"
            fi
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

require_xcframework "$XCFRAMEWORK_PATH"

if [ -z "$EXPECTED_VERSION" ]; then
    EXPECTED_VERSION="$(read_swift_user_module_version \
        --file "$SCRIPT_DIR/../Sources/Configuration/Versioning.xcconfig")"
fi

begin_group "Validate XCFramework Swift module version: $XCFRAMEWORK_PATH"
log_info "Expected user module version: $EXPECTED_VERSION"

validation_errors=0
interfaces_checked=0

while IFS= read -r -d '' interface_path; do
    interfaces_checked=$((interfaces_checked + 1))
    relative_path="${interface_path#"$XCFRAMEWORK_PATH"/}"
    module_flags="$(grep -m 1 '^// swift-module-flags:' "$interface_path" || true)"

    if [ -z "$module_flags" ]; then
        log_error "$relative_path: missing swift-module-flags header"
        validation_errors=$((validation_errors + 1))
        continue
    fi

    actual_version="$(printf '%s\n' "$module_flags" \
        | awk '{ for (i = 1; i < NF; i++) if ($i == "-user-module-version") { print $(i + 1); exit } }')"

    if [ -z "$actual_version" ]; then
        log_error "$relative_path: missing -user-module-version"
        validation_errors=$((validation_errors + 1))
    elif [ "$actual_version" != "$EXPECTED_VERSION" ]; then
        log_error "$relative_path: -user-module-version is '$actual_version', expected '$EXPECTED_VERSION'"
        validation_errors=$((validation_errors + 1))
    fi
done < <(find "$XCFRAMEWORK_PATH" -name "*.swiftinterface" -type f -print0)

end_group

if [ "$interfaces_checked" -eq 0 ]; then
    log_info "No .swiftinterface files found in $XCFRAMEWORK_PATH, skipping"
    exit 0
fi

if [ "$validation_errors" -ne 0 ]; then
    log_error "Swift module version validation failed with $validation_errors error(s)."
    exit 1
fi

log_info "Swift module version validation passed ($interfaces_checked interface(s) checked)."
