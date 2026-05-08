#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

XCFRAMEWORK_PATH=""

usage() {
    log_notice "Usage: $0 --xcframework <path>"
    log_notice "  --xcframework <path>    XCFramework bundle to validate (required)"
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

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    log_error "XCFramework path does not exist: $XCFRAMEWORK_PATH"
    exit 1
fi

info_plist_path="$XCFRAMEWORK_PATH/Info.plist"
if [ ! -f "$info_plist_path" ]; then
    log_error "Missing XCFramework Info.plist: $info_plist_path"
    exit 1
fi

normalize_archs() {
    local archs="$1"

    printf "%s\n" "$archs" | tr " " "\n" | sed "/^$/d" | sort | paste -sd " " -
}

binary_path_for_library() {
    local library_identifier="$1"
    local library_path="$2"
    local library_full_path="$XCFRAMEWORK_PATH/$library_identifier/$library_path"
    local framework_name=""
    local binary_path=""

    if [[ "$library_full_path" == *.framework ]]; then
        framework_name="$(basename "$library_full_path" .framework)"
        binary_path="$library_full_path/$framework_name"
        if [ -e "$binary_path" ]; then
            printf "%s\n" "$binary_path"
            return 0
        fi

        binary_path="$library_full_path/Versions/A/$framework_name"
        if [ -e "$binary_path" ]; then
            printf "%s\n" "$binary_path"
            return 0
        fi

        log_error "Missing framework binary for $library_identifier: $library_full_path" >&2
        return 1
    fi

    if [ -f "$library_full_path" ]; then
        printf "%s\n" "$library_full_path"
        return 0
    fi

    log_error "Unsupported or missing library path for $library_identifier: $library_full_path" >&2
    return 1
}

validate_library_architectures() {
    local library_identifier="$1"
    local library_path="$2"
    local expected_archs="$3"
    local binary_path=""
    local actual_archs=""
    local normalized_expected_archs=""
    local normalized_actual_archs=""

    if ! binary_path="$(binary_path_for_library "$library_identifier" "$library_path")"; then
        return 1
    fi

    if ! actual_archs="$(lipo -archs "$binary_path" 2>/dev/null)"; then
        log_error "Could not read architectures for $library_identifier: $binary_path"
        return 1
    fi

    normalized_expected_archs="$(normalize_archs "$expected_archs")"
    normalized_actual_archs="$(normalize_archs "$actual_archs")"

    if [ "$normalized_expected_archs" != "$normalized_actual_archs" ]; then
        log_error "$library_identifier architecture mismatch: expected [$normalized_expected_archs], got [$normalized_actual_archs]"
        log_error "Binary: $binary_path"
        return 1
    fi

    log_notice "$library_identifier architectures: $normalized_actual_archs"
}

begin_group "Validate XCFramework architectures: $XCFRAMEWORK_PATH"

xcframework_json="$(plutil -convert json -o - "$info_plist_path")"
validation_errors=0
processed_libraries=0

library_records="$(
    printf "%s\n" "$xcframework_json" \
        | jq -r '.AvailableLibraries[] | [.LibraryIdentifier, .LibraryPath, (.SupportedArchitectures | join(" "))] | @tsv'
)" || {
    log_error "Could not parse AvailableLibraries from $info_plist_path"
    end_group
    exit 1
}

while IFS=$'\t' read -r library_identifier library_path expected_archs; do
    if [ -z "$library_identifier" ]; then
        continue
    fi

    processed_libraries=$((processed_libraries + 1))

    if ! validate_library_architectures "$library_identifier" "$library_path" "$expected_archs"; then
        validation_errors=$((validation_errors + 1))
    fi
done <<< "$library_records"

if [ "$processed_libraries" -eq 0 ]; then
    log_error "XCFramework Info.plist does not contain any AvailableLibraries entries."
    validation_errors=$((validation_errors + 1))
fi

end_group

if [ "$validation_errors" -ne 0 ]; then
    log_error "XCFramework architecture validation failed with $validation_errors error(s)."
    exit 1
fi

log_notice "XCFramework architecture validation passed."
