#!/bin/bash

# CI ratchet: ensures SentryCrash import count doesn't increase in SDK sources.
# Decrease MAX_IMPORTS as phases eliminate imports. Never increase it.

set -euo pipefail

# Source CI utilities for proper logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

# Baseline count of #import / #include lines referencing SentryCrash from SDK sources
# (excludes Sources/SentryCrash/). Pattern allows whitespace after '#' so indented
# directives under #if are counted, and matches #include as well as #import.
MAX_IMPORTS=85

count=$(grep -rnE '#[[:space:]]*(import|include).*SentryCrash' Sources/Sentry Sources/Swift \
    --include='*.m' --include='*.h' --include='*.c' --include='*.mm' --include='*.cpp' \
    | grep -vc 'Sources/SentryCrash/' \
    | tr -d ' ')

if [ "$count" -gt "$MAX_IMPORTS" ]; then
    log_error "SentryCrash import count increased from $MAX_IMPORTS to $count"
    log_error "New #import / #include of SentryCrash from SDK files is not allowed."
    log_error "Use the SentryCrashReporter protocol instead."
    echo ""
    log_notice "Offending imports:"
    grep -rnE '#[[:space:]]*(import|include).*SentryCrash' Sources/Sentry Sources/Swift \
        --include='*.m' --include='*.h' --include='*.c' --include='*.mm' --include='*.cpp' \
        | grep -v 'Sources/SentryCrash/'
    exit 1
fi

log_notice "SentryCrash import ratchet: $count / $MAX_IMPORTS (OK)"
