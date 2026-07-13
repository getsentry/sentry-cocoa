#!/bin/bash
set -euo pipefail

# Generic banned-pattern linter for Objective-C sources (.m/.mm/.h).
#
# Flags every line matching --pattern that is not inside a suppression region:
#
#   // sentry-lint:disable <rule>
#   ... intentionally-banned code ...
#   // sentry-lint:enable <rule>
#
# A disable without a matching enable suppresses to end of file; state resets per
# file. The rule id is chosen by the caller via --rule, so several patterns can be
# checked independently with their own suppression markers.

# Source CI utilities for proper logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

# Parse named arguments
PATTERN=""
RULE=""
SEARCH_PATH=""
MESSAGE=""

usage() {
    log_notice "Usage: $0 --pattern <ere> --rule <id> --path <dir> [--message <text>]"
    log_notice "  --pattern <ere>   Extended regex to ban (plain strings match literally) (required)"
    log_notice "  --rule <id>       Suppression marker id: // sentry-lint:disable <id> (required)"
    log_notice "  --path <dir>      Directory scanned recursively for .m/.mm/.h sources (required)"
    log_notice "  --message <text>  Custom guidance shown on violations (optional)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --pattern) PATTERN="$2"; shift 2 ;;
        --rule)    RULE="$2";    shift 2 ;;
        --path)    SEARCH_PATH="$2"; shift 2 ;;
        --message) MESSAGE="$2"; shift 2 ;;
        *)         usage ;;
    esac
done

[ -z "$PATTERN" ]     && { log_error "Error: --pattern is required"; usage; }
[ -z "$RULE" ]        && { log_error "Error: --rule is required"; usage; }
[ -z "$SEARCH_PATH" ] && { log_error "Error: --path is required"; usage; }
[ -z "$MESSAGE" ] && MESSAGE="Banned pattern '$PATTERN' found."

# Pre-filter to candidate files so awk never reads from stdin on an empty match set.
FILES=$(grep -rlE "$PATTERN" "$SEARCH_PATH" \
    --include='*.m' --include='*.mm' --include='*.h' || true)
[ -z "$FILES" ] && exit 0

# Report lines matching PATTERN outside a // sentry-lint:disable/enable <rule> region.
# Disable/enable lines are consumed before the pattern check, so a marker line is
# never itself reported even for broad patterns.
# shellcheck disable=SC2086  # intentional word-splitting; source paths have no spaces
OFFENDING=$(awk -v pat="$PATTERN" -v rule="$RULE" '
    BEGIN { dis="sentry-lint:disable[[:space:]]+" rule; ena="sentry-lint:enable[[:space:]]+" rule }
    FNR==1 { off=0 }
    $0 ~ dis { off=1; next }
    $0 ~ ena { off=0; next }
    off { next }
    $0 ~ pat { print FILENAME":"FNR": "$0 }
' $FILES)

if [ -n "$OFFENDING" ]; then
    log_error "$MESSAGE"
    log_error "Wrap intentional use in // sentry-lint:disable $RULE ... // sentry-lint:enable $RULE."
    echo "$OFFENDING"
    exit 1
fi
