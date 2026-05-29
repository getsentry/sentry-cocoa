#!/bin/bash
set -euo pipefail

# Extract public Swift API declarations using swift-api-digester.
#
# Runs swift-api-digester on a built xcframework to produce a stable JSON
# dump of the module's public API surface. Used by update-api.sh for
# Sentry and SentrySwiftUI modules.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

MODULE=""
OUTPUT=""
FRAMEWORK_PATHS=()

usage() {
    log_notice "Usage: $0"
    log_notice "  --module <name>           Swift module name (required)"
    log_notice "  --output <path>           Output JSON file path (required)"
    log_notice "  --framework-path <path>   Framework search path (required, repeatable)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --module)         MODULE="$2";                          shift 2 ;;
        --output)         OUTPUT="$2";                          shift 2 ;;
        --framework-path) FRAMEWORK_PATHS+=("$2");              shift 2 ;;
        *)                usage ;;
    esac
done

if [ -z "$MODULE" ]; then
    log_error "Error: --module is required"
    usage
fi

if [ -z "$OUTPUT" ]; then
    log_error "Error: --output is required"
    usage
fi

if [ ${#FRAMEWORK_PATHS[@]} -eq 0 ]; then
    log_error "Error: at least one --framework-path is required"
    usage
fi

# Delete private .swiftinterface files from each framework path so only
# public interfaces are analyzed.
for fw_path in "${FRAMEWORK_PATHS[@]}"; do
    log_info "Deleting private .swiftinterface files from $fw_path"
    # The framework path points inside the xcframework (e.g. .../ios-arm64_arm64e).
    # Walk up one level to find the xcframework root for the find.
    xcfw_root="$(dirname "$fw_path")"
    find "$xcfw_root" -name "*.private.swiftinterface" -type f -delete
done

# Build the -iframework arguments
IFRAMEWORK_ARGS=()
for fw_path in "${FRAMEWORK_PATHS[@]}"; do
    IFRAMEWORK_ARGS+=("-iframework" "$fw_path")
done

log_info "Running swift-api-digester for $MODULE module"
xcrun --sdk iphoneos swift-api-digester \
    -dump-sdk \
    -o "$OUTPUT" \
    -abort-on-module-fail \
    -avoid-tool-args \
    -avoid-location \
    -module "$MODULE" \
    -target arm64-apple-ios10.0 \
    "${IFRAMEWORK_ARGS[@]}"

log_info "Sorting JSON keys and arrays for stable output"
jq -S 'walk(if type == "array" then sort_by(tostring) else . end)' "$OUTPUT" > "$OUTPUT.tmp" && mv "$OUTPUT.tmp" "$OUTPUT"

log_info "$MODULE API written to $OUTPUT"
