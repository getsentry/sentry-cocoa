#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

VERSION=""

usage() {
    cat <<EOF
Usage: $(basename "$0") --version <version>

Build the VersionBump utility and update the version across all source files.

OPTIONS:
    --version <version>     Target version string, e.g. 9.13.0 (required)

EXAMPLES:
    $(basename "$0") --version 9.13.0
    $(basename "$0") --version 9.13.0-rc.0

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

if [ -z "$VERSION" ]; then
    log_error "--version is required"
    usage
fi

begin_group "Build VersionBump"
cd "$SCRIPT_DIR/../Utils/VersionBump" && swift build
cd "$SCRIPT_DIR/.."
end_group

begin_group "Bump version to ${VERSION}"
./Utils/VersionBump/.build/debug/VersionBump --update "${VERSION}"
end_group

log_info "Version bump to ${VERSION} completed successfully"
