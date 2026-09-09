#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

XCFRAMEWORK_PATH=""
BUILD_CONSUMER=false

usage() {
    log_notice "Usage: $0 --xcframework <path> [--build-consumer]"
    log_notice "  --xcframework <path>    SentryObjC static XCFramework to validate (required)"
    log_notice "  --build-consumer        Build the macOS CMake consumer and fail on warnings"
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
        --build-consumer)
            BUILD_CONSUMER=true
            shift
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

XCFRAMEWORK_PATH="$(cd "$XCFRAMEWORK_PATH" && pwd)"
STATIC_LIBRARIES=()
while IFS= read -r -d '' static_library; do
    STATIC_LIBRARIES+=( "$static_library" )
done < <(find "$XCFRAMEWORK_PATH" -mindepth 2 -maxdepth 2 \
    -name "libSentryObjC.a" -type f -print0)

if [ ${#STATIC_LIBRARIES[@]} -eq 0 ]; then
    log_error "No SentryObjC static libraries found in $XCFRAMEWORK_PATH"
    exit 1
fi

for static_library in "${STATIC_LIBRARIES[@]}"; do
    # Universal XCFramework slices contain more than the host architecture, so inspect every
    # architecture explicitly. `-a` includes STABS entries, where OSO records identify the
    # producer's object files that dsymutil would otherwise try to load from unavailable CI paths.
    if ! nm_output="$(nm -arch all -ap "$static_library")"; then
        log_error "Could not inspect static library debug maps: $static_library"
        exit 1
    fi
    if grep ' OSO ' <<< "$nm_output" > /dev/null; then
        log_error "Static library contains debug-map references to external object files: $static_library"
        exit 1
    fi
done

log_info "SentryObjC static libraries contain no external debug maps"

if [ "$BUILD_CONSUMER" = false ]; then
    exit 0
fi

MACOS_LIBRARY="$XCFRAMEWORK_PATH/macos-arm64_x86_64/libSentryObjC.a"
if [ ! -f "$MACOS_LIBRARY" ]; then
    log_notice "No macOS slice found, skipping the CMake consumer build"
    exit 0
fi

REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sentryobjc-static-cmake.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cmake \
    -S "$REPOSITORY_ROOT/Samples/macOS-ObjectiveC-Static-CMake" \
    -B "$BUILD_DIR" \
    -G Xcode \
    -DSENTRY_OBJC_STATIC_XCFRAMEWORK="$XCFRAMEWORK_PATH"

set -o pipefail
if ! cmake --build "$BUILD_DIR" --config Release 2>&1 \
    | awk '{ print } /warning:/ { found = 1 } END { exit found }'; then
    log_error "CMake consumer build failed or emitted warnings"
    exit 1
fi

DSYM_PATH="$BUILD_DIR/Release/macOS-ObjectiveC-Static-CMake.dSYM"
if [ ! -d "$DSYM_PATH" ]; then
    log_error "CMake consumer dSYM was not generated"
    exit 1
fi

dsym_binary="$DSYM_PATH/Contents/Resources/DWARF/macOS-ObjectiveC-Static-CMake"

if ! dsym_symbols="$(nm -arch all -gjU "$dsym_binary")"; then
    log_error "Could not inspect consumer dSYM symbols"
    exit 1
fi

expected_symbols=(
    "_sentrycrash_install"
    '_OBJC_CLASS_$_SentryObjCSDK'
)

for symbol in "${expected_symbols[@]}"; do
    if ! grep -Fx "$symbol" <<< "$dsym_symbols" > /dev/null; then
        log_error "Expected symbol missing from consumer dSYM: $symbol"
        exit 1
    fi
done
log_info "SentryObjC static library builds without debug-symbol warnings"
