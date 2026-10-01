#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SCHEME=""
SUFFIX=""
CONFIGURATION_SUFFIX=""
SDKS=""
ARCHIVE_TEMPLATE=""
PRODUCT_NAME=""
OUTPUT=""

usage() {
    log_info "Usage: $0 --scheme <name> --sdks <list> --archive-template <path> [options]"
    log_info "  -s, --scheme <name>                 Scheme used for output naming (required)"
    log_info "  -d, --sdks <list>                   Comma-separated SDKs (required)"
    log_info "  -a, --archive-template <path>      Archive path with SDK_NAME placeholder (required)"
    log_info "  -u, --suffix <suffix>               Output name suffix (default: empty)"
    log_info "  -c, --configuration-suffix <value> Framework product suffix (default: empty)"
    log_info "  -p, --product-name <name>           Framework product name (default: scheme)"
    log_info "  -o, --output <path>                 Output xcframework (default: scheme+suffix.xcframework)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ $# -lt 2 && "$1" != -h && "$1" != --help ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case "$1" in
        -s|--scheme)               SCHEME="$2"; shift 2 ;;
        -d|--sdks)                 SDKS="$2"; shift 2 ;;
        -a|--archive-template)     ARCHIVE_TEMPLATE="$2"; shift 2 ;;
        -u|--suffix)               SUFFIX="$2"; shift 2 ;;
        -c|--configuration-suffix) CONFIGURATION_SUFFIX="$2"; shift 2 ;;
        -p|--product-name)         PRODUCT_NAME="$2"; shift 2 ;;
        -o|--output)               OUTPUT="$2"; shift 2 ;;
        -h|--help)                 usage ;;
        *)                         log_error "Unknown argument: $1"; usage ;;
    esac
done

if [[ -z "$SCHEME" || -z "$SDKS" || -z "$ARCHIVE_TEMPLATE" ]]; then
    log_error "--scheme, --sdks and --archive-template are required"
    usage
fi

PRODUCT_NAME="${PRODUCT_NAME:-$SCHEME}"
OUTPUT="${OUTPUT:-$SCHEME$SUFFIX.xcframework}"
IFS=',' read -r -a sdks <<< "$SDKS"
framework_filename="$PRODUCT_NAME$CONFIGURATION_SUFFIX.framework"

log_info "Assembling $OUTPUT from ${sdks[*]} ($framework_filename)"

# SDK_NAME can occur more than once in CI archive paths.
archive_framework() {
    local archive_path="$1"
    local framework_path="$archive_path/Products/Library/Frameworks/$framework_filename"
    if [[ ! -d "$framework_path" ]]; then
        log_error "Missing framework: $framework_path"
        return 1
    fi
    xcodebuild_args+=(-framework "$framework_path")
    local dsym_path="$archive_path/dSYMs/$framework_filename.dSYM"
    if [[ -d "$dsym_path" ]]; then
        xcodebuild_args+=(-debug-symbols "$dsym_path")
    fi
}

xcodebuild_args=(-create-xcframework)
begin_group "Collecting framework slices"
for sdk in "${sdks[@]}"; do
    archive_path="${ARCHIVE_TEMPLATE//SDK_NAME/$sdk}"
    archive_framework "$archive_path"

    # CI can provide the Catalyst framework alongside the macOS archive.
    if [[ "$sdk" == "macosx" ]]; then
        catalyst_path="${ARCHIVE_TEMPLATE//SDK_NAME/maccatalyst}/Library/Frameworks"
        if [[ -d "$catalyst_path/$framework_filename" ]]; then
            xcodebuild_args+=(-framework "$catalyst_path/$framework_filename")
            if [[ -d "$catalyst_path/dSYMs/$framework_filename.dSYM" ]]; then
                xcodebuild_args+=(-debug-symbols "$catalyst_path/dSYMs/$framework_filename.dSYM")
            fi
        fi
    fi
done
end_group

if [[ "$OUTPUT" != *.xcframework ]]; then
    log_error "Output must end in .xcframework: $OUTPUT"
    exit 1
fi
rm -rf -- "$OUTPUT"
begin_group "Creating $OUTPUT"
xcodebuild "${xcodebuild_args[@]}" -output "$OUTPUT"
end_group
