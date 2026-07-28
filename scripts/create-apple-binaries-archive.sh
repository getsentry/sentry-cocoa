#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

VERSION=""
OUTPUT_DIR=""
XCFRAMEWORK_DIR="XCFrameworkBuildPath"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Create a .tgz archive for the sentry-apple-binaries distribution repo.
Copies the binary Package.swift template, stamps in the release version
and xcframework checksums, and tars the result alongside the SentryCppHelper
source and .gitignore.

OPTIONS:
    --version <ver>             Release version, e.g. 9.24.0 (required)
    --xcframework-dir <path>    Directory containing *.xcframework.zip files
                                (default: XCFrameworkBuildPath)
    --output-dir <path>         Directory to write the archive to (default: repo root)
    -h, --help                  Show this help message

EXAMPLES:
    $(basename "$0") --version 9.24.0
    $(basename "$0") --version 9.24.0 --output-dir XCFrameworkBuildPath

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)         VERSION="$2";         shift 2 ;;
        --xcframework-dir) XCFRAMEWORK_DIR="$2"; shift 2 ;;
        --output-dir)      OUTPUT_DIR="$2";      shift 2 ;;
        -h|--help)         usage ;;
        *)                 log_error "Unknown option: $1"; usage ;;
    esac
done

if [ -z "$VERSION" ]; then
    log_error "--version is required"
    usage
fi

REPO_ROOT="$SCRIPT_DIR/.."
DIST_DIR="$REPO_ROOT/distribution/apple-binaries"

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$REPO_ROOT"
fi

if [ ! -f "$DIST_DIR/Package.swift" ]; then
    log_error "distribution/apple-binaries/Package.swift not found"
    exit 1
fi

ZIPS_AND_MARKERS=(
    "Sentry.xcframework.zip|Sentry-Static"
    "Sentry-Dynamic.xcframework.zip|Sentry-Dynamic"
    "SentryObjC-Dynamic.xcframework.zip|SentryObjC-Dynamic"
    "SentryObjC-Static.xcframework.zip|SentryObjC-Static"
)

ARCHIVE_NAME="sentry-apple-binaries.tgz"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

begin_group "Create $ARCHIVE_NAME"

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

cp "$DIST_DIR/Package.swift" "$STAGING_DIR/Package.swift"
cp "$DIST_DIR/.gitignore" "$STAGING_DIR/.gitignore"
mkdir -p "$STAGING_DIR/Sources/SentryCppHelper"
cp "$DIST_DIR/Sources/SentryCppHelper/SentryCppHelper.swift" "$STAGING_DIR/Sources/SentryCppHelper/SentryCppHelper.swift"

log_info "Stamping version $VERSION into Package.swift"
sed -i.bak "s|releases/download/[^/]*/|releases/download/${VERSION}/|g" "$STAGING_DIR/Package.swift"
rm -f "$STAGING_DIR/Package.swift.bak"

log_info "Updating checksums from $XCFRAMEWORK_DIR"
for entry in "${ZIPS_AND_MARKERS[@]}"; do
    zip="${entry%%|*}"
    marker="${entry##*|}"
    zip_path="${XCFRAMEWORK_DIR}/${zip}"
    if [ ! -f "$zip_path" ]; then
        log_error "Missing ${marker}: ${zip_path} not found"
        exit 1
    fi
    checksum=$(shasum -a 256 "$zip_path" | awk '{print $1}')
    sed -i.bak "s/checksum: \".*\" \/\/${marker}/checksum: \"${checksum}\" \/\/${marker}/" "$STAGING_DIR/Package.swift"
    rm -f "$STAGING_DIR/Package.swift.bak"
    log_info "  ${marker}: ${checksum}"
done

tar -czf "$ARCHIVE_PATH" \
    -C "$STAGING_DIR" \
    Package.swift \
    Sources/SentryCppHelper/SentryCppHelper.swift \
    .gitignore

log_info "Created $ARCHIVE_PATH"
log_info "Contents:"
tar -tzf "$ARCHIVE_PATH"

end_group
