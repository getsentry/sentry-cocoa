#!/bin/bash

# CI ratchet: ensures SentryCrash import count doesn't increase in SDK sources.
# Decrease MAX_IMPORTS as phases eliminate imports. Never increase it.

set -euo pipefail

# Source CI utilities for proper logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

MAX_IMPORTS=84

count=$(grep -rEn '#[[:space:]]*(import|include).*SentryCrash' Sources/Sentry Sources/Swift \
    --include='*.m' --include='*.h' --include='*.c' --include='*.mm' \
    | wc -l \
    | tr -d ' ')

if [ "$count" -gt "$MAX_IMPORTS" ]; then
    log_error "SentryCrash import count increased from $MAX_IMPORTS to $count"
    log_error "New imports from SDK files into SentryCrash headers are not allowed."
    log_error "Use the SentryCrashReporter protocol instead."
    echo ""
    log_notice "Offending imports:"
    grep -rEn '#[[:space:]]*(import|include).*SentryCrash' Sources/Sentry Sources/Swift \
        --include='*.m' --include='*.h' --include='*.c' --include='*.mm'
    exit 1
fi

log_notice "SentryCrash import ratchet: $count / $MAX_IMPORTS (OK)"
