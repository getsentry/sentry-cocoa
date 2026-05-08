#!/bin/bash
set -euxo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [platform] [podspec] [library_type] [extra_args...]

Run 'pod lib lint' for a Sentry podspec.

ARGUMENTS:
    platform        Target platform (default: ios)
    podspec         Pod spec name: Sentry or SentrySwiftUI (default: Sentry)
    library_type    'dynamic' or 'static' (default: dynamic)
    extra_args      Additional arguments passed to 'pod lib lint'

EXAMPLES:
    $(basename "$0") ios Sentry dynamic
    $(basename "$0") macos SentrySwiftUI dynamic
    $(basename "$0") ios Sentry static

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

PLATFORM="${1:-ios}"
POD_SPEC=${2:-Sentry}
LIBRARY_TYPE="${3:-dynamic}"
INCLUDE_POD_SPECS=""
EXTRA_ARGS=""

log_info "Pod lib lint:"
log_info "  Platform:     $PLATFORM"
log_info "  Pod spec:     $POD_SPEC"
log_info "  Library type: $LIBRARY_TYPE"

case $POD_SPEC in
"Sentry")
    INCLUDE_POD_SPECS=""
    ;;
"SentrySwiftUI")
    INCLUDE_POD_SPECS="--include-podspecs=Sentry.podspec"
    ;;
*)
    log_error "pod lib lint: Unknown podspec '$POD_SPEC'. Expected 'Sentry' or 'SentrySwiftUI'"
    usage
    ;;
esac

case $LIBRARY_TYPE in
"static")
    EXTRA_ARGS="--use-libraries"
    ;;
*)
    EXTRA_ARGS=""
    ;;
esac

begin_group "pod lib lint $POD_SPEC ($PLATFORM, $LIBRARY_TYPE)"
pod lib lint --verbose --platforms="$PLATFORM" "$POD_SPEC".podspec $INCLUDE_POD_SPECS $EXTRA_ARGS "${@:4}"
end_group
