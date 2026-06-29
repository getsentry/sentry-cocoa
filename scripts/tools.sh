#!/usr/bin/env bash

# Shared utility functions for build scripts.
# This file is intended to be sourced from other scripts.
# Requires ci-utils.sh to be sourced first.

# Read a value from an xcconfig file by exact key match.
#
# Usage: read_xcconfig_value --key <key> --file <xcconfig_file>
read_xcconfig_value() {
    local key="" file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --key)  key="$2";  shift 2 ;;
            --file) file="$2"; shift 2 ;;
            *)      log_error "read_xcconfig_value: unknown arg: $1"; return 1 ;;
        esac
    done
    awk -F ' *= *' -v key="$key" '$1 == key { print $2; exit }' "$file"
}

# Read a value from an xcconfig file, exit with an error if the key is missing or empty.
#
# Usage: read_xcconfig_value_or_exit --key <key> --file <xcconfig_file>
read_xcconfig_value_or_exit() {
    local value
    value="$(read_xcconfig_value "$@")"
    if [ -z "$value" ]; then
        log_error "xcconfig lookup failed for: $*"
        exit 1
    fi
    printf '%s' "$value"
}
