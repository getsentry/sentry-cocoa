#!/bin/bash
#
# Assembles a SentryObjC-Static.xcframework from per-SDK static libraries.
#
# Takes a path template containing "SDK_NAME" as a placeholder and the public
# headers directory, then creates the xcframework with -library + -headers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SDKS=""
LIB_PATH_TEMPLATE=""
FRAMEWORK_PATH_TEMPLATE=""
HEADERS_DIR=""
OUTPUT_NAME="SentryObjC-Static"

usage() {
    log_notice "Usage: $0"
    log_notice "  --sdks <list>                     Comma-separated SDKs (required)"
    log_notice "  --lib-path-template <path>        Static library path template with SDK_NAME placeholder"
    log_notice "  --framework-path-template <path>  Framework path template with SDK_NAME placeholder"
    log_notice "  --headers <path>                  Public headers directory (required with --lib-path-template)"
    log_notice "  --output-name <name>              Output xcframework name (default: SentryObjC-Static)"
    log_notice ""
    log_notice "Provide either --lib-path-template (static) or --framework-path-template (dynamic)."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sdks)                    SDKS="$2";                    shift 2 ;;
        --lib-path-template)       LIB_PATH_TEMPLATE="$2";       shift 2 ;;
        --framework-path-template) FRAMEWORK_PATH_TEMPLATE="$2"; shift 2 ;;
        --headers)                 HEADERS_DIR="$2";              shift 2 ;;
        --output-name)             OUTPUT_NAME="$2";              shift 2 ;;
        -h|--help)                 usage ;;
        *)                         log_error "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$SDKS" ]; then
    log_error "Error: --sdks is required"
    usage
fi
if [ -z "$LIB_PATH_TEMPLATE" ] && [ -z "$FRAMEWORK_PATH_TEMPLATE" ]; then
    log_error "Error: --lib-path-template or --framework-path-template is required"
    usage
fi
if [ -n "$LIB_PATH_TEMPLATE" ] && [ -n "$FRAMEWORK_PATH_TEMPLATE" ]; then
    log_error "Error: provide only one of --lib-path-template or --framework-path-template"
    usage
fi
if [ -n "$LIB_PATH_TEMPLATE" ] && [ -z "$HEADERS_DIR" ]; then
    log_error "Error: --headers is required with --lib-path-template"
    usage
fi
if [ -n "$HEADERS_DIR" ] && [ ! -d "$HEADERS_DIR" ]; then
    log_error "Headers directory not found: $HEADERS_DIR"
    exit 1
fi

IFS=',' read -r -a sdk_list <<< "$SDKS"

xcframework_path="$OUTPUT_NAME.xcframework"
rm -rf "$xcframework_path"

create_args=( -create-xcframework )

if [ -n "$LIB_PATH_TEMPLATE" ]; then
    begin_group "Collecting static library slices"
    for sdk in "${sdk_list[@]}"; do
        lib_path="${LIB_PATH_TEMPLATE//SDK_NAME/$sdk}"
        if [ ! -f "$lib_path" ]; then
            log_error "Static library not found: $lib_path"
            exit 1
        fi
        log_info "  $sdk: $lib_path"
        create_args+=( -library "$lib_path" -headers "$HEADERS_DIR" )
    done
    end_group
else
    begin_group "Collecting framework slices"
    for sdk in "${sdk_list[@]}"; do
        fw_path="${FRAMEWORK_PATH_TEMPLATE//SDK_NAME/$sdk}"
        if [ ! -d "$fw_path" ]; then
            log_error "Framework not found: $fw_path"
            exit 1
        fi
        log_info "  $sdk: $fw_path"
        create_args+=( -framework "$fw_path" )
        dsym_path="${fw_path}.dSYM"
        if [ -d "$dsym_path" ]; then
            log_info "  dSYM: $dsym_path"
            create_args+=( -debug-symbols "$dsym_path" )
        fi
    done
    end_group
fi

create_args+=( -output "$xcframework_path" )

begin_group "Create $xcframework_path"
xcodebuild "${create_args[@]}"
end_group

log_info "Built $xcframework_path"
