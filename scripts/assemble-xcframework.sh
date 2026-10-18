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
FRAMEWORK_TEMPLATE=""
LIBRARY_TEMPLATE=""
HEADERS=""
PRODUCT_NAME=""
OUTPUT=""

usage() {
    log_info "Usage: $0 --sdks <list> (--archive-template|--framework-template|--library-template) <path> [options]"
    log_info "  -d, --sdks <list>                   Comma-separated SDKs (required)"
    log_info "  -a, --archive-template <path>      XCArchive path with SDK_NAME placeholder"
    log_info "  -f, --framework-template <path>    Framework path with SDK_NAME placeholder"
    log_info "  -l, --library-template <path>      Static library path with SDK_NAME placeholder"
    log_info "  -H, --headers <path>               Public headers (required with --library-template)"
    log_info "  -s, --scheme <name>                 Scheme for archived frameworks and default output name"
    log_info "  -u, --suffix <suffix>               Output name suffix (default: empty)"
    log_info "  -c, --configuration-suffix <value> Archived framework product suffix (default: empty)"
    log_info "  -p, --product-name <name>           Archived framework name (default: scheme)"
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
        -f|--framework-template)   FRAMEWORK_TEMPLATE="$2"; shift 2 ;;
        -l|--library-template)     LIBRARY_TEMPLATE="$2"; shift 2 ;;
        -H|--headers)             HEADERS="$2"; shift 2 ;;
        -u|--suffix)               SUFFIX="$2"; shift 2 ;;
        -c|--configuration-suffix) CONFIGURATION_SUFFIX="$2"; shift 2 ;;
        -p|--product-name)         PRODUCT_NAME="$2"; shift 2 ;;
        -o|--output)               OUTPUT="$2"; shift 2 ;;
        -h|--help)                 usage ;;
        *)                         log_error "Unknown argument: $1"; usage ;;
    esac
done

if [[ -z "$SDKS" ]]; then
    log_error "--sdks is required"
    usage
fi
template_count=0
for template in "$ARCHIVE_TEMPLATE" "$FRAMEWORK_TEMPLATE" "$LIBRARY_TEMPLATE"; do
    if [[ -n "$template" ]]; then
        template_count=$((template_count + 1))
    fi
done
if [[ "$template_count" -ne 1 ]]; then
    log_error "Provide exactly one of --archive-template, --framework-template or --library-template"
    usage
fi
if [[ -n "$ARCHIVE_TEMPLATE" && -z "$SCHEME" ]]; then
    log_error "--scheme is required with --archive-template"
    usage
fi
if [[ -n "$LIBRARY_TEMPLATE" ]]; then
    if [[ -z "$HEADERS" || ! -d "$HEADERS" ]]; then
        log_error "--headers must point to a directory with --library-template"
        usage
    fi
elif [[ -n "$HEADERS" ]]; then
    log_error "--headers is only supported with --library-template"
    usage
fi
if [[ -z "$OUTPUT" && -z "$SCHEME" ]]; then
    log_error "--output or --scheme is required"
    usage
fi

PRODUCT_NAME="${PRODUCT_NAME:-$SCHEME}"
OUTPUT="${OUTPUT:-$SCHEME$SUFFIX.xcframework}"
IFS=',' read -r -a sdks <<< "$SDKS"
framework_filename="$PRODUCT_NAME$CONFIGURATION_SUFFIX.framework"

log_info "Assembling $OUTPUT from ${sdks[*]}"

add_framework() {
    local framework_path="$1"
    local dsym_path="$2"
    if [[ ! -d "$framework_path" ]]; then
        log_error "Missing framework: $framework_path"
        return 1
    fi
    xcodebuild_args+=(-framework "$framework_path")
    if [[ -d "$dsym_path" ]]; then
        xcodebuild_args+=(-debug-symbols "$(cd "$dsym_path" && pwd)")
    fi
}

add_library() {
    local library_path="$1"
    if [[ ! -f "$library_path" ]]; then
        log_error "Missing library: $library_path"
        return 1
    fi
    xcodebuild_args+=(-library "$library_path" -headers "$HEADERS")
}

xcodebuild_args=(-create-xcframework)
begin_group "Collecting slices"
for sdk in "${sdks[@]}"; do
    if [[ -n "$LIBRARY_TEMPLATE" ]]; then
        add_library "${LIBRARY_TEMPLATE//SDK_NAME/$sdk}"
    elif [[ -n "$FRAMEWORK_TEMPLATE" ]]; then
        framework_path="${FRAMEWORK_TEMPLATE//SDK_NAME/$sdk}"
        add_framework "$framework_path" "$framework_path.dSYM"
    else
        # SDK_NAME may occur more than once in CI archive paths.
        archive_path="${ARCHIVE_TEMPLATE//SDK_NAME/$sdk}"
        add_framework "$archive_path/Products/Library/Frameworks/$framework_filename" \
            "$archive_path/dSYMs/$framework_filename.dSYM"

        # CI can provide the Catalyst framework alongside the macOS archive.
        if [[ "$sdk" == "macosx" ]]; then
            catalyst_path="${ARCHIVE_TEMPLATE//SDK_NAME/maccatalyst}/Library/Frameworks"
            if [[ -d "$catalyst_path/$framework_filename" ]]; then
                add_framework "$catalyst_path/$framework_filename" \
                    "$catalyst_path/dSYMs/$framework_filename.dSYM"
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
