#!/bin/bash
set -euo pipefail

# Verifies the installed XcodeGen matches scripts/.xcodegen-version.
# Older versions silently drop unsupported spec keys (e.g. package traits),
# producing broken projects, so fail fast before generating.

# Source CI utilities for proper logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

EXPECTED_VERSION="$(cat "$SCRIPT_DIR/.xcodegen-version")"
INSTALLED_VERSION="$(xcodegen --version | awk -F ': ' '{print $2}')"

if [ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]; then
    log_error "XcodeGen version mismatch: installed $INSTALLED_VERSION, expected $EXPECTED_VERSION. In CI this usually means stale Homebrew formula metadata; locally run 'make init' to update."
    exit 1
fi
