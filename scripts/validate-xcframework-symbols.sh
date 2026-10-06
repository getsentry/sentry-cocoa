#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
# shellcheck source=./xcframework-utils.sh disable=SC1091
source "$SCRIPT_DIR/xcframework-utils.sh"

XCFRAMEWORK_PATH=""

usage() {
    log_info "Usage: $0 --xcframework <path>"
    log_info "  --xcframework <path>    XCFramework bundle to validate (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --xcframework)
            if [ $# -lt 2 ]; then
                usage
            fi
            XCFRAMEWORK_PATH="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$XCFRAMEWORK_PATH" ]; then
    log_error "Error: --xcframework is required"
    usage
fi

require_xcframework "$XCFRAMEWORK_PATH"
info_plist_path="$XCFRAMEWORK_PATH/Info.plist"

# shellcheck disable=SC2016
extract_objc_class_symbols() {
    local binary_path="$1"
    local arch="$2"

    nm -arch "$arch" -gUj "$binary_path" 2>/dev/null \
        | grep -E '_OBJC_(META)?CLASS_\$_' \
        | sort \
        || true
}

validate_library_symbols() {
    local library_identifier="$1"
    local library_path="$2"
    local binary_path=""
    local archs=""
    local arch_array=()
    local ref_arch=""
    local errors=0

    if ! binary_path="$(binary_path_for_library "$XCFRAMEWORK_PATH" "$library_identifier" "$library_path")"; then
        return 1
    fi

    if ! archs="$(xcrun lipo -archs "$binary_path" 2>/dev/null)"; then
        log_error "Could not read architectures for $library_identifier: $binary_path"
        return 1
    fi

    read -ra arch_array <<< "$archs"

    if [ "${#arch_array[@]}" -lt 2 ]; then
        log_info "$library_identifier: single architecture (${arch_array[*]}), skipping symbol comparison"
        return 0
    fi

    ref_arch="${arch_array[0]}"
    local ref_symbols
    ref_symbols="$(extract_objc_class_symbols "$binary_path" "$ref_arch")"

    for arch in "${arch_array[@]:1}"; do
        local other_symbols
        other_symbols="$(extract_objc_class_symbols "$binary_path" "$arch")"

        local only_in_ref
        only_in_ref="$(comm -23 <(printf "%s\n" "$ref_symbols") <(printf "%s\n" "$other_symbols"))"

        local only_in_other
        only_in_other="$(comm -13 <(printf "%s\n" "$ref_symbols") <(printf "%s\n" "$other_symbols"))"

        if [ -n "$only_in_ref" ]; then
            local count
            count="$(printf "%s\n" "$only_in_ref" | wc -l | tr -d ' ')"
            log_error "$library_identifier: $ref_arch has $count ObjC class symbol(s) missing from $arch:"
            printf "%s\n" "$only_in_ref" | while IFS= read -r sym; do
                log_error "  $sym"
            done
            errors=$((errors + 1))
        fi

        if [ -n "$only_in_other" ]; then
            local count
            count="$(printf "%s\n" "$only_in_other" | wc -l | tr -d ' ')"
            log_error "$library_identifier: $arch has $count ObjC class symbol(s) missing from $ref_arch:"
            printf "%s\n" "$only_in_other" | while IFS= read -r sym; do
                log_error "  $sym"
            done
            errors=$((errors + 1))
        fi
    done

    if [ "$errors" -eq 0 ]; then
        log_info "$library_identifier: ObjC class symbols consistent across architectures (${arch_array[*]})"
    fi

    return "$errors"
}

begin_group "Validate XCFramework symbol consistency: $XCFRAMEWORK_PATH"

xcframework_json="$(plutil -convert json -o - "$info_plist_path")"
validation_errors=0
processed_libraries=0

library_records="$(
    printf "%s\n" "$xcframework_json" \
        | jq -r '.AvailableLibraries[] | [.LibraryIdentifier, .LibraryPath] | @tsv'
)" || {
    log_error "Could not parse AvailableLibraries from $info_plist_path"
    end_group
    exit 1
}

while IFS=$'\t' read -r library_identifier library_path; do
    if [ -z "$library_identifier" ]; then
        continue
    fi

    processed_libraries=$((processed_libraries + 1))

    if ! validate_library_symbols "$library_identifier" "$library_path"; then
        validation_errors=$((validation_errors + 1))
    fi
done <<< "$library_records"

if [ "$processed_libraries" -eq 0 ]; then
    log_error "XCFramework Info.plist does not contain any AvailableLibraries entries."
    validation_errors=$((validation_errors + 1))
fi

end_group

if [ "$validation_errors" -ne 0 ]; then
    log_error "XCFramework symbol consistency check failed with $validation_errors error(s)."
    exit 1
fi

log_info "XCFramework symbol consistency check passed."
