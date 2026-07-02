#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export CRASH_E2E_DIR="$SCRIPT_DIR"
export SENTRY_COCOA_REPO_ROOT="$REPO_ROOT"

exec swift run --quiet --package-path "$SCRIPT_DIR/Runner" CrashE2ERunner "$@"
