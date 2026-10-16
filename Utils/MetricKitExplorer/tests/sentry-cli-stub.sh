#!/bin/bash
# AI-generated development aid for MetricKit Explorer, not a human-reviewed,
# verified source of correctness. Take its assumptions and coverage with a grain
# of salt, and independently validate important behavior.
set -euo pipefail

printf '%s\n' "$*" >>"$FIXTURE_DIR/legacy-calls"
if [[ "${LEGACY_MODE:-}" = failure ]]; then exit 2; fi
if [[ "${LEGACY_MODE:-}" = invalid-json ]]; then
    printf 'not-json\n'
    exit 1
fi

# Never let tests search the developer's machine, even if discovery regresses.
if [[ "$1 $2" = 'debug-files find' ]]; then
    [[ " $* " = *' --no-cwd '* && " $* " = *' --no-well-known '* && " $* " = *' --path '* ]] || {
        echo 'Unbounded symbol discovery is forbidden in tests.' >&2
        exit 2
    }
fi
exec "$REAL_LEGACY_CLI" "$@"
