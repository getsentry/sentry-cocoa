#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

OUTPUT_DIR=""
INTEGRATION=""
ALL=false

INTEGRATIONS_DIR="3rd-party-integrations"

ALL_DIR_NAMES="SentrySwiftLog SentrySwiftyBeaver SentryPulse SentryCocoaLumberjack"

archive_name_for() {
    case "$1" in
        SentrySwiftLog)       echo "sentry-apple-swift-log" ;;
        SentrySwiftyBeaver)   echo "sentry-apple-swiftybeaver" ;;
        SentryPulse)          echo "sentry-apple-pulse" ;;
        SentryCocoaLumberjack) echo "sentry-apple-cocoalumberjack" ;;
        *) echo "" ;;
    esac
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Create .tgz archives for 3rd-party integration distribution repos.
Copies sources, tests, README, .gitignore, and LICENSE.md.

OPTIONS:
    --integration <name>        Directory name under $INTEGRATIONS_DIR
                                (e.g. SentrySwiftLog)
    --all                       Archive all integrations
    --output-dir <path>         Directory to write archives to (default: repo root)
    -h, --help                  Show this help message

EXAMPLES:
    $(basename "$0") --all
    $(basename "$0") --integration SentrySwiftLog
    $(basename "$0") --all --output-dir XCFrameworkBuildPath

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --integration) INTEGRATION="$2"; shift 2 ;;
        --all)         ALL=true;         shift ;;
        --output-dir)  OUTPUT_DIR="$2";  shift 2 ;;
        -h|--help)     usage ;;
        *)             log_error "Unknown option: $1"; usage ;;
    esac
done

if [ "$ALL" = false ] && [ -z "$INTEGRATION" ]; then
    log_error "Either --all or --integration <name> is required"
    usage
fi

REPO_ROOT="$SCRIPT_DIR/.."

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$REPO_ROOT"
fi

create_archive() {
    local dir_name="$1"
    local archive_name
    archive_name=$(archive_name_for "$dir_name")
    local src_dir="$REPO_ROOT/$INTEGRATIONS_DIR/$dir_name"

    if [ -z "$archive_name" ]; then
        log_error "Unknown integration: $dir_name"
        exit 1
    fi

    if [ ! -d "$src_dir" ]; then
        log_error "Directory not found: $src_dir"
        exit 1
    fi

    local archive_file="$archive_name.tgz"
    local archive_path="$OUTPUT_DIR/$archive_file"

    begin_group "Create $archive_file"

    local staging_dir
    staging_dir=$(create_staging_dir)

    cp "$src_dir/Package.swift" "$staging_dir/Package.swift"
    cp "$src_dir/.gitignore" "$staging_dir/.gitignore"
    cp "$src_dir/README.md" "$staging_dir/README.md"
    cp "$REPO_ROOT/LICENSE.md" "$staging_dir/LICENSE.md"

    cp -R "$src_dir/Sources" "$staging_dir/Sources"
    cp -R "$src_dir/Tests" "$staging_dir/Tests"

    create_tgz_from_staging "$staging_dir" "$archive_path"

    end_group
}

if [ "$ALL" = true ]; then
    for dir_name in $ALL_DIR_NAMES; do
        create_archive "$dir_name"
    done
else
    create_archive "$INTEGRATION"
fi
