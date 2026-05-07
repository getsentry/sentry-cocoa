#!/bin/bash

set -e

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <xcarchive_path> <excluded_architecture>

Remove a specific architecture from all framework binaries in an XCArchive.

ARGUMENTS:
    xcarchive_path          Path to the .xcarchive directory
    excluded_architecture   Architecture to remove (e.g., arm64e)

EXAMPLES:
    $(basename "$0") xcframework-slices/iphoneos.xcarchive arm64e
    $(basename "$0") XCFrameworkBuildPath/archive/iphoneos.xcarchive arm64e

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [ $# -ne 2 ]; then
    log_error "Expected 2 arguments (xcarchive_path, excluded_architecture), got $#"
    usage
fi

XCARCHIVE_PATH="$1"
EXCLUDED_ARCH="$2"

if [ ! -d "$XCARCHIVE_PATH" ]; then
    log_error "XCArchive path does not exist: $XCARCHIVE_PATH"
    exit 1
fi

if [ -z "$EXCLUDED_ARCH" ]; then
    log_warning "No excluded architecture specified, nothing to do"
    exit 0
fi

echo "Remove architecture:"
echo "  XCArchive path: $XCARCHIVE_PATH"
echo "  Architecture:   $EXCLUDED_ARCH"

# Find all framework directories and process their binaries
find "$XCARCHIVE_PATH" -name "*.framework" -type d | while read -r framework_path; do
    binary_path="$framework_path/$(basename "$framework_path" .framework)"
    if [ -L "$binary_path" ]; then
        echo "Resolving symlink at path: $binary_path"
        binary_path=$(readlink -f "$binary_path")
    fi
    if [ -f "$binary_path" ]; then
        begin_group "Processing binary: $binary_path"

        # Check what architectures are currently in the binary
        echo "Current architectures in binary:"
        lipo -info "$binary_path"

        should_remove=""

        # Check if the excluded architectures are actually present
        if lipo -info "$binary_path" | grep -q "$EXCLUDED_ARCH"; then
            echo "Architecture '$EXCLUDED_ARCH' found in binary, will remove it"
            should_remove=true
        else
            log_warning "Architecture '$EXCLUDED_ARCH' not found in binary, skipping removal"
        fi

        # Only perform removal if there are architectures to remove
        if [ -n "$should_remove" ]; then
            echo "Removing architectures: $EXCLUDED_ARCH"
            temp_binary="${binary_path}.tmp"
            lipo -remove "$EXCLUDED_ARCH" "$binary_path" -output "$temp_binary"
            mv "$temp_binary" "$binary_path"
            echo "Updated binary: $binary_path"
        else
            echo "No architectures to remove for this binary"
        fi

        end_group
    fi
done

echo "Architecture removal completed successfully."
