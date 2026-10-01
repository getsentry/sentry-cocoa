#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

OLD_VERSION=""
NEW_VERSION=""

usage() {
    log_info "Usage: $0 --old-version <version> --new-version <version>"
    log_info "  -o, --old-version <version>   Current SDK version (required)"
    log_info "  -n, --new-version <version>   New SDK version (required)"
    log_info "  Craft release automation may still supply two positional versions."
    exit 1
}

# Craft invokes this script with two positional versions during releases.
if [[ $# -eq 2 && "$1" != -* ]]; then
    OLD_VERSION="$1"
    NEW_VERSION="$2"
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--old-version)
                if [[ $# -lt 2 ]]; then log_error "Missing value for $1"; usage; fi
                OLD_VERSION="$2"; shift 2 ;;
            -n|--new-version)
                if [[ $# -lt 2 ]]; then log_error "Missing value for $1"; usage; fi
                NEW_VERSION="$2"; shift 2 ;;
            -h|--help) usage ;;
            *) log_error "Unknown argument: $1"; usage ;;
        esac
    done
fi

if [[ -z "$OLD_VERSION" || -z "$NEW_VERSION" ]]; then
    log_error "--old-version and --new-version are required"
    usage
fi

log_info "Bumping version:"
log_info "  Old version: $OLD_VERSION"
log_info "  New version: $NEW_VERSION"

"$SCRIPT_DIR/bump-version.sh" --version "${NEW_VERSION}"

begin_group "Update package SHA"
"$SCRIPT_DIR/update-package-sha.sh"
end_group

log_info "Version bump from ${OLD_VERSION} to ${NEW_VERSION} completed successfully"
