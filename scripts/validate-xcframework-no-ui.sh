#!/bin/bash
# Check direct Mach-O dependencies in the distributed NoUI binary, not its build products.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./xcframework-utils.sh disable=SC1091
source "$SCRIPT_DIR/xcframework-utils.sh"

xcframework=""
usage() {
    log_info "Usage: $0 -x|--xcframework <path>   Unpacked NoUI XCFramework (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -x|--xcframework) [[ $# -ge 2 ]] || usage; xcframework="$2"; shift 2 ;;
        *) usage ;;
    esac
done
[[ -n "$xcframework" ]] || usage
require_xcframework "$xcframework"

libraries="$(plutil -convert json -o - "$xcframework/Info.plist" |
    jq -er '.AvailableLibraries[] | [.LibraryIdentifier, .LibraryPath] | @tsv')"
while IFS=$'\t' read -r slice library; do
    if [[ "$library" != SentryWithoutUIKit.framework ]]; then
        log_error "Expected SentryWithoutUIKit.framework in $slice, got $library"
        exit 1
    fi
    binary="$(binary_path_for_library "$xcframework" "$slice" "$library")"
    dependencies="$(xcrun otool -arch all -L "$binary")"
    if grep -E '/(UIKit|AppKit|SwiftUI)\.framework/|/libswift(UIKit|AppKit|SwiftUI)\.dylib' <<< "$dependencies"; then
        log_error "Unexpected UI linkage in $binary"
        exit 1
    fi
done <<< "$libraries"
log_info "No direct UI linkage in $xcframework"
