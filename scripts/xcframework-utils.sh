#!/bin/bash
# Shared XCFramework metadata and binary lookup helpers. Source after ci-utils.sh.

require_xcframework() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        log_error "XCFramework path does not exist: $path"
        return 1
    fi
    if [[ ! -f "$path/Info.plist" ]]; then
        log_error "Missing XCFramework Info.plist: $path/Info.plist"
        return 1
    fi
}

binary_path_for_library() {
    local xcframework_path="$1"
    local library_identifier="$2"
    local library_path="$3"
    local library_full_path="$xcframework_path/$library_identifier/$library_path"
    local framework_name binary_path

    if [[ "$library_full_path" == *.framework ]]; then
        framework_name="$(basename "$library_full_path" .framework)"
        for binary_path in "$library_full_path/$framework_name" "$library_full_path/Versions/A/$framework_name"; do
            if [[ -e "$binary_path" ]]; then
                printf '%s\n' "$binary_path"
                return 0
            fi
        done
        log_error "Missing framework binary for $library_identifier: $library_full_path" >&2
        return 1
    fi

    if [[ -f "$library_full_path" ]]; then
        printf '%s\n' "$library_full_path"
        return 0
    fi
    log_error "Unsupported or missing library path for $library_identifier: $library_full_path" >&2
    return 1
}
