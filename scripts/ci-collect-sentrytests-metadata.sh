#!/bin/bash
set -euo pipefail

# Source CI utilities for proper logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

DERIVED_DATA_ROOT="$HOME/Library/Developer/Xcode/DerivedData"
OUTPUT_DIR=""
BUNDLE_NAME="SentryTests"

usage() {
    log_notice "Usage: $0"
    log_notice "  --derived-data-root <path>    DerivedData root (default: $HOME/Library/Developer/Xcode/DerivedData)"
    log_notice "  --output-dir <path>           Output directory (required)"
    log_notice "  --bundle-name <name>          Test bundle name without .xctest (default: SentryTests)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --derived-data-root)
            DERIVED_DATA_ROOT="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --bundle-name)
            BUNDLE_NAME="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            ;;
    esac
done

if [ -z "$OUTPUT_DIR" ]; then
    log_error "Error: --output-dir is required"
    usage
fi

find_latest_file() {
    local pattern="$1"
    local latest=""

    while IFS= read -r -d '' candidate; do
        if [ -z "$latest" ] || [ "$candidate" -nt "$latest" ]; then
            latest="$candidate"
        fi
    done < <(find "$DERIVED_DATA_ROOT" -path "$pattern" -type f -print0)

    echo "$latest"
}

mkdir -p "$OUTPUT_DIR"

BINARY_PATH=$(find_latest_file "*/Build/Products/*/${BUNDLE_NAME}.xctest/${BUNDLE_NAME}")
if [ -z "$BINARY_PATH" ]; then
    log_error "Failed to locate ${BUNDLE_NAME}.xctest/${BUNDLE_NAME} under $DERIVED_DATA_ROOT"
    exit 1
fi

LINK_FILE_LIST_PATH=$(find_latest_file "*/Build/Intermediates.noindex/*/${BUNDLE_NAME}.build/Objects-normal/*/${BUNDLE_NAME}.LinkFileList")
if [ -z "$LINK_FILE_LIST_PATH" ]; then
    log_error "Failed to locate ${BUNDLE_NAME}.LinkFileList under $DERIVED_DATA_ROOT"
    exit 1
fi

INFO_PLIST_PATH="$(dirname "$BINARY_PATH")/Info.plist"
if [ ! -f "$INFO_PLIST_PATH" ]; then
    log_error "Failed to locate Info.plist next to $BINARY_PATH"
    exit 1
fi

ARCHS=$(lipo -archs "$BINARY_PATH")
if [[ " $ARCHS " == *" arm64 "* ]]; then
    ARCH="arm64"
else
    ARCH=$(echo "$ARCHS" | awk '{print $1}')
fi

UUID_OUTPUT_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.uuid.txt"
CLASS_LIST_OUTPUT_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.class-list.txt"
CLASS_LIST_TOP_OUTPUT_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.class-list-top-50.txt"
SUMMARY_OUTPUT_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.summary.txt"
LINK_FILE_LIST_OUTPUT_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.LinkFileList"
INFO_PLIST_OUTPUT_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.Info.plist"

xcrun dwarfdump -u "$BINARY_PATH" > "$UUID_OUTPUT_PATH"
cp "$LINK_FILE_LIST_PATH" "$LINK_FILE_LIST_OUTPUT_PATH"
cp "$INFO_PLIST_PATH" "$INFO_PLIST_OUTPUT_PATH"

otool -arch "$ARCH" -ov "$BINARY_PATH" | awk '
    BEGIN { count = 0 }
    /^0[0-9a-f]+ .* _OBJC_CLASS_\$_/ {
        line = $0
        sub(/^.*_OBJC_CLASS_\$_/, "", line)
        printf "%d\t%s\n", count, line
        count++
    }
' > "$CLASS_LIST_OUTPUT_PATH"

head -n 50 "$CLASS_LIST_OUTPUT_PATH" > "$CLASS_LIST_TOP_OUTPUT_PATH"

CLASS_COUNT=$(wc -l < "$CLASS_LIST_OUTPUT_PATH" | tr -d ' ')
FIRST_CLASS=$(awk 'NR == 1 { print $2 }' "$CLASS_LIST_OUTPUT_PATH")
PRINCIPAL_CLASS=$(/usr/libexec/PlistBuddy -c 'Print NSPrincipalClass' "$INFO_PLIST_PATH" 2>/dev/null || true)

{
    echo "bundle_name=${BUNDLE_NAME}"
    echo "binary_path=${BINARY_PATH}"
    echo "info_plist_path=${INFO_PLIST_PATH}"
    echo "link_file_list_path=${LINK_FILE_LIST_PATH}"
    echo "selected_arch=${ARCH}"
    echo "archs=${ARCHS}"
    echo "principal_class=${PRINCIPAL_CLASS:-<not set>}"
    echo "class_count=${CLASS_COUNT}"
    echo "first_class=${FIRST_CLASS:-<none>}"
} > "$SUMMARY_OUTPUT_PATH"

begin_group "${BUNDLE_NAME} metadata"
cat "$SUMMARY_OUTPUT_PATH"
end_group
