#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

XCARCHIVE_PATH=""
EXCLUDED_ARCH=""

usage() {
    log_info "Usage: $0 --xcarchive <path> --excluded-arch <architecture>"
    log_info "  -a, --xcarchive <path>           Directory containing xcarchives (required)"
    log_info "  -x, --excluded-arch <name>      Architecture to remove, e.g. arm64e (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ $# -lt 2 && "$1" != -h && "$1" != --help ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case "$1" in
        -a|--xcarchive)     XCARCHIVE_PATH="$2"; shift 2 ;;
        -x|--excluded-arch) EXCLUDED_ARCH="$2"; shift 2 ;;
        -h|--help)          usage ;;
        *)                  log_error "Unknown argument: $1"; usage ;;
    esac
done

if [[ -z "$XCARCHIVE_PATH" || -z "$EXCLUDED_ARCH" ]]; then
    log_error "--xcarchive and --excluded-arch are required"
    usage
fi

if [ ! -d "$XCARCHIVE_PATH" ]; then
    log_error "XCArchive path does not exist: $XCARCHIVE_PATH"
    exit 1
fi

log_info "Remove architecture:"
log_info "  XCArchive path: $XCARCHIVE_PATH"
log_info "  Architecture:   $EXCLUDED_ARCH"

# Find all framework directories and process their binaries
find "$XCARCHIVE_PATH" -name "*.framework" -type d | while read -r framework_path; do
    binary_path="$framework_path/$(basename "$framework_path" .framework)"
    if [ -L "$binary_path" ]; then
        log_info "Resolving symlink at path: $binary_path"
        binary_path=$(readlink -f "$binary_path")
    fi
    if [ -f "$binary_path" ]; then
        begin_group "Processing binary: $binary_path"

        # Check what architectures are currently in the binary
        log_info "Current architectures in binary:"
        lipo -info "$binary_path"

        should_remove=""

        # Check if the excluded architectures are actually present
        if lipo -info "$binary_path" | grep -q "$EXCLUDED_ARCH"; then
            log_info "Architecture '$EXCLUDED_ARCH' found in binary, will remove it"
            should_remove=true
        else
            log_warning "Architecture '$EXCLUDED_ARCH' not found in binary, skipping removal"
        fi

        # Only perform removal if there are architectures to remove
        if [ -n "$should_remove" ]; then
            log_info "Removing architectures: $EXCLUDED_ARCH"
            temp_binary="${binary_path}.tmp"
            lipo -remove "$EXCLUDED_ARCH" "$binary_path" -output "$temp_binary"
            mv "$temp_binary" "$binary_path"
            log_info "Updated binary: $binary_path"
        else
            log_info "No architectures to remove for this binary"
        fi

        end_group
    fi
done

log_info "Architecture removal completed successfully."
