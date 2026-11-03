#!/bin/bash
set -euo pipefail

# Extract public Swift API declarations using swift-api-digester.
#
# Runs swift-api-digester on built frameworks or SwiftPM modules to produce
# a stable JSON dump. Used by update-api.sh for framework and SwiftPM builds.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

MODULES=()
OUTPUT=""
FRAMEWORK_PATHS=()
INCLUDE_PATHS=()

usage() {
    log_info "Usage: $0"
    log_info "  --module <name>           Module to extract (required, repeatable)"
    log_info "  --output <path>           Formatted JSON file path (required)"
    log_info "  --framework-path <path>   Framework search path (repeatable)"
    log_info "  --include-path <path>     Swift module or header search path (repeatable)"
    log_info "At least one framework or include path is required."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --module)
            [[ -n "$2" ]] || usage
            MODULES+=("$2"); shift 2 ;;
        --output)         OUTPUT="$2";                          shift 2 ;;
        --framework-path) FRAMEWORK_PATHS+=("$2");              shift 2 ;;
        --include-path)   INCLUDE_PATHS+=("$2");                shift 2 ;;
        *)                usage ;;
    esac
done

if [ ${#MODULES[@]} -eq 0 ]; then
    log_error "Error: --module is required"
    usage
fi

if [ -z "$OUTPUT" ]; then
    log_error "Error: --output is required"
    usage
fi

if [ ${#FRAMEWORK_PATHS[@]} -eq 0 ] && [ ${#INCLUDE_PATHS[@]} -eq 0 ]; then
    log_error "Error: at least one --framework-path or --include-path is required"
    usage
fi

# Delete private .swiftinterface files from each framework path so only
# public interfaces are analyzed.
for fw_path in ${FRAMEWORK_PATHS[@]+"${FRAMEWORK_PATHS[@]}"}; do
    log_info "Deleting private .swiftinterface files from $fw_path"
    # The framework path points inside the xcframework (e.g. .../ios-arm64_arm64e).
    # Walk up one level to find the xcframework root for the find.
    xcfw_root="$(dirname "$fw_path")"
    find "$xcfw_root" -name "*.private.swiftinterface" -type f -delete
done

MODULE_ARGS=()
for module in "${MODULES[@]}"; do
    MODULE_ARGS+=(-module "$module")
    # Source builds also contain serialized modules, which include private imports.
    if [ ${#INCLUDE_PATHS[@]} -gt 0 ]; then
        MODULE_ARGS+=(-use-interface-for-module "$module")
    fi
done
SEARCH_ARGS=()
for fw_path in ${FRAMEWORK_PATHS[@]+"${FRAMEWORK_PATHS[@]}"}; do
    SEARCH_ARGS+=(-iframework "$fw_path")
done
for include_path in ${INCLUDE_PATHS[@]+"${INCLUDE_PATHS[@]}"}; do
    SEARCH_ARGS+=(-I "$include_path")
done

log_info "Running swift-api-digester for ${MODULES[*]}"
xcrun --sdk iphoneos swift-api-digester \
    -dump-sdk \
    -o "$OUTPUT" \
    -abort-on-module-fail \
    -avoid-tool-args \
    -avoid-location \
    "${MODULE_ARGS[@]}" \
    -target arm64-apple-ios10.0 \
    "${SEARCH_ARGS[@]}"

log_info "Sorting JSON keys and arrays for stable output"
jq -S 'walk(if type == "array" then sort_by(tostring) else . end)' "$OUTPUT" > "$OUTPUT.tmp" && mv "$OUTPUT.tmp" "$OUTPUT"

log_info "${MODULES[*]} API written to $OUTPUT"
