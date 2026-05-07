#!/bin/bash
set -eux
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "${SCRIPT_DIR}/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <old_version> <new_version>

Bump the SDK version across all source files and update the package SHA.

ARGUMENTS:
    old_version     Current version string (e.g., 9.12.0)
    new_version     New version string (e.g., 9.13.0)

EXAMPLES:
    $(basename "$0") 9.12.0 9.13.0

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ $# -lt 2 ]]; then
    log_error "Expected 2 arguments (old_version, new_version), got $#"
    usage
fi

OLD_VERSION="${1}"
NEW_VERSION="${2}"

echo "Bumping version:"
echo "  Old version: $OLD_VERSION"
echo "  New version: $NEW_VERSION"

begin_group "Build VersionBump"
cd Utils/VersionBump && swift build
cd "$SCRIPT_DIR/.."
end_group

begin_group "Bump version from ${OLD_VERSION} to ${NEW_VERSION}"
./Utils/VersionBump/.build/debug/VersionBump --update "${NEW_VERSION}"
end_group

begin_group "Update package SHA"
./scripts/update-package-sha.sh
end_group

echo "Version bump from ${OLD_VERSION} to ${NEW_VERSION} completed successfully"
