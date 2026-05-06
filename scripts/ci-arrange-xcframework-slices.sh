#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SDKS=""

usage() {
    log_notice "Usage: $0"
    log_notice "  --sdks <value>    Comma-separated list of SDK slices (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sdks)  SDKS="$2";  shift 2 ;;
        *)       usage ;;
    esac
done

if [ -z "$SDKS" ]; then
    log_error "Error: --sdks is required"
    usage
fi

mkdir -p XCFrameworkBuildPath/archive

arrange_slices() {
    local variant_id="$1"
    local slice_dir="$2"
    local archive_name="$3"

    IFS=',' read -r -a sdk_list <<< "$SDKS"
    for sdk in "${sdk_list[@]}"; do
        artifact_dir="${slice_dir}/xcframework-${variant_id}-slice-${sdk}"
        zip_file=$(find "$artifact_dir" -name "*.xcarchive.zip" -type f | head -1)
        if [ -z "$zip_file" ]; then
            log_error "No xcarchive.zip found in $artifact_dir"
            exit 1
        fi
        unzip_dir="/tmp/sentryobjc-unzip-${variant_id}-${sdk}"
        rm -rf "$unzip_dir"
        mkdir -p "$unzip_dir"
        unzip -q "$zip_file" -d "$unzip_dir"
        mkdir -p "XCFrameworkBuildPath/archive/${archive_name}"
        mv "$unzip_dir/${sdk}.xcarchive" "XCFrameworkBuildPath/archive/${archive_name}/${sdk}.xcarchive"
        rm -rf "$unzip_dir"
    done
}

arrange_slices "sentry-static" "xcframework-slices/sentry-static" "Sentry"
arrange_slices "sentryobjc-types" "xcframework-slices/sentryobjc-types" "SentryObjCTypes"
arrange_slices "sentryobjc-bridge" "xcframework-slices/sentryobjc-bridge" "SentryObjCBridge"
arrange_slices "sentryobjc-objc" "xcframework-slices/sentryobjc-objc" "SentryObjC"

echo "Archive layout:"
find XCFrameworkBuildPath/archive -maxdepth 3 -type d | head -30
