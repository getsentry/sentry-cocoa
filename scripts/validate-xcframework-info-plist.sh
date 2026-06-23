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
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown argument: $1"
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

REQUIRED_KEYS=(
    CFBundleExecutable
    CFBundleIdentifier
    CFBundleInfoDictionaryVersion
    CFBundleName
    CFBundlePackageType
    CFBundleShortVersionString
    CFBundleSupportedPlatforms
    CFBundleVersion
)

NONEMPTY_KEYS=(
    CFBundleExecutable
    CFBundleIdentifier
    CFBundleName
    CFBundleShortVersionString
    CFBundleSupportedPlatforms
    CFBundleVersion
)

begin_group "Validate XCFramework Info.plist: $XCFRAMEWORK_PATH"

validation_errors=0
frameworks_checked=0

while IFS= read -r -d '' framework_path; do
    framework_name="$(basename "$framework_path" .framework)"
    info_plist="$framework_path/Info.plist"

    if [ ! -f "$info_plist" ]; then
        versions_plist="$framework_path/Versions/Current/Resources/Info.plist"
        if [ -f "$versions_plist" ]; then
            info_plist="$versions_plist"
        else
            log_error "$framework_name: Info.plist not found"
            validation_errors=$((validation_errors + 1))
            continue
        fi
    fi

    frameworks_checked=$((frameworks_checked + 1))
    plist_json="$(plutil -convert json -o - "$info_plist")"

    # Native macOS frameworks use LSMinimumSystemVersion; all others (including Mac Catalyst) use MinimumOSVersion
    has_ls="$(printf '%s' "$plist_json" | jq -r '.LSMinimumSystemVersion // empty')"
    if [ -n "$has_ls" ]; then
        os_version_key="LSMinimumSystemVersion"
    else
        os_version_key="MinimumOSVersion"
    fi

    for key in "${REQUIRED_KEYS[@]}" "$os_version_key"; do
        value="$(printf '%s' "$plist_json" | jq -r --arg k "$key" '.[$k] // empty')"
        if [ -z "$value" ]; then
            log_error "$framework_name: missing required key '$key'"
            validation_errors=$((validation_errors + 1))
        fi
    done

    for key in "${NONEMPTY_KEYS[@]}" "$os_version_key"; do
        value="$(printf '%s' "$plist_json" | jq -r --arg k "$key" '.[$k] // empty')"
        if [ -z "$value" ]; then
            continue
        fi
        if [ "$value" = "0.0.0" ]; then
            log_error "$framework_name: key '$key' has invalid value '$value'"
            validation_errors=$((validation_errors + 1))
        fi
    done
done < <(find "$XCFRAMEWORK_PATH" -name "*.framework" -type d -print0)

if [ "$frameworks_checked" -eq 0 ]; then
    log_notice "No .framework bundles found in $XCFRAMEWORK_PATH (static library xcframework), skipping"
    end_group
    exit 0
fi

end_group

if [ "$validation_errors" -ne 0 ]; then
    log_error "Info.plist validation failed with $validation_errors error(s)."
    exit 1
fi

log_notice "Info.plist validation passed ($frameworks_checked framework(s) checked)."
