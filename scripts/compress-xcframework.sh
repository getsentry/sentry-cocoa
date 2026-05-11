#!/bin/bash

set -eoux pipefail

# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <signed> <framework>

Optionally sign and then compress an XCFramework into a zip archive.

ARGUMENTS:
    signed       '--sign' to codesign with the Sentry certificate, or empty string to skip
    framework    XCFramework name without extension (e.g., Sentry-Dynamic)

EXAMPLES:
    $(basename "$0") --sign Sentry-Dynamic
    $(basename "$0") "" Sentry

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ $# -lt 2 ]]; then
    log_error "Expected 2 arguments (signed, framework), got $#"
    usage
fi

should_sign_arg="${1}"
framework="${2}"

should_sign=false
[[ "$should_sign_arg" == "--sign" ]] && should_sign=true

sentry_certificate="Apple Distribution: GetSentry LLC (97JCY7859U)"
framework_path="$framework.xcframework"

log_info "Compress XCFramework:"
log_info "  Framework: $framework"
log_info "  Path:      $framework_path"
log_info "  Signing:   $should_sign"

if [[ "$should_sign" == true ]]; then
    begin_group "Signing $framework"
    log_info "Signing with certificate: $sentry_certificate"
    codesign --sign "$sentry_certificate" --timestamp --options runtime --deep --force "$framework_path"
    end_group
fi

begin_group "Compressing $framework"
ditto -c -k -X --rsrc --keepParent "$framework_path" "$framework_path.zip"
log_info "Created $framework_path.zip"
end_group
