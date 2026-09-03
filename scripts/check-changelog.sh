#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKDOWNLINT_CLI2_VERSION="0.23.2"
PATHS=()
RUN_TESTS=true

usage() {
    log_notice "Usage: $0"
    log_notice "  -p, --path <file>     Changelog file to check (repeatable;"
    log_notice "                        default: CHANGELOG.md and CHANGELOG_V10.md)"
    log_notice "  --skip-tests          Skip the custom rule unit tests"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path) PATHS+=("$2"); shift 2 ;;
        --skip-tests) RUN_TESTS=false; shift ;;
        *) usage ;;
    esac
done

cd "$REPO_ROOT"

if [ "$RUN_TESTS" = true ]; then
    begin_group "Changelog rule unit tests"
    node "$SCRIPT_DIR/markdownlint/changelog-no-duplicate-sections.test.cjs"
    end_group
fi

if ! command -v npx >/dev/null; then
    log_error "npx is required to run markdownlint-cli2"
    exit 1
fi

begin_group "markdownlint-cli2 changelog check"
if [ ${#PATHS[@]} -eq 0 ]; then
    npx --yes "markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}"
else
    npx --yes "markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}" --no-globs "${PATHS[@]}"
fi
end_group
