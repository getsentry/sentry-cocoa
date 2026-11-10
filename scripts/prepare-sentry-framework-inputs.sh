#!/bin/bash
# Prepare Sentry's headers, Swift interfaces, and resources, independent of linkage type.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SOURCE_HEADERS_DIR="$SCRIPT_DIR/../Sources/Sentry/Public"
SWIFT_ARCHIVE=""
OUTPUT_DIR=""

usage() {
    log_info "Usage: $0"
    log_info "  -a, --swift-archive <path>    Source archive containing Sentry Swift artifacts (required)"
    log_info "  -o, --output-dir <path>       Staging directory for Headers, Modules, Resources (required)"
    log_info "Use the same SDK_V10 environment setting as the source archive."
    exit 1
}

while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || usage
    case $1 in
        -a|--swift-archive) SWIFT_ARCHIVE="$2" ;;
        -o|--output-dir) OUTPUT_DIR="$2" ;;
        *) usage ;;
    esac
    shift 2
done

[[ -n "$SWIFT_ARCHIVE" && -n "$OUTPUT_DIR" ]] || usage
swift_products="$SWIFT_ARCHIVE/Products/Swift"
if [ ! -d "$swift_products/Sentry.swiftmodule" ] || [ ! -f "$swift_products/Sentry-Swift.h" ]; then
    log_error "Missing Swift artifacts for Sentry in $SWIFT_ARCHIVE"
    exit 1
fi

validate_output_location() {
    local output_ancestor="$OUTPUT_DIR" input_dir

    # Resolve without creating directories inside an input, including through symlinks.
    while [ ! -e "$output_ancestor" ]; do
        output_ancestor="$(dirname "$output_ancestor")"
    done
    output_ancestor="$(cd "$output_ancestor" && pwd -P)"

    for input_dir in "$SOURCE_HEADERS_DIR" "$SWIFT_ARCHIVE"; do
        input_dir="$(cd "$input_dir" && pwd -P)"
        if [[ "$output_ancestor/" == "$input_dir/"* ]]; then
            log_error "Output directory must not be inside the source headers or archive: $OUTPUT_DIR"
            exit 1
        fi
        if [ -d "$OUTPUT_DIR" ] && [[ "$input_dir/" == "$output_ancestor/"* ]]; then
            log_error "Output directory must not contain the source headers or archive: $OUTPUT_DIR"
            exit 1
        fi
    done
}

prepare_headers() {
    local header
    cp "$SOURCE_HEADERS_DIR"/*.h "$headers_dir/"
    {
        # Configure V10 before any public declarations, without consumer compiler flags.
        if [ "${SDK_V10:-0}" = 1 ]; then
            cp "$SCRIPT_DIR/../Sources/SentryV10Configuration/include/SentryV10Configuration.h" "$headers_dir/"
            printf '#import <Sentry/SentryV10Configuration.h>\n'
        fi
        for header in "$SOURCE_HEADERS_DIR"/*.h; do
            printf '#import <Sentry/%s>\n' "${header##*/}"
        done
    } > "$headers_dir/SentryHeaders.h"
}

prepare_modules() {
    local interface has_interface=false
    for interface in "$swift_products/Sentry.swiftmodule"/*.swiftinterface; do
        [ -f "$interface" ] || continue
        [[ "$interface" != *.package.swiftinterface ]] || continue
        # Never rename the compiled Swift module. Only fold its public Clang module into Sentry.
        if ! grep -Eq -- '-module-name Sentry( |$)' "$interface"; then
            log_error "Swift module name does not match Sentry: $interface"
            exit 1
        fi
        # Keep public and SPI interfaces, not serialized modules with producer-only search paths.
        # Swift 6.4 qualifies module types with ::; preserve either compiler spelling.
        sed -E 's/(^|[^[:alnum:]_])SentryHeaders([.]|::|$)/\1Sentry\2/g' \
            "$interface" > "$modules_dir/Sentry.swiftmodule/${interface##*/}"
        has_interface=true
    done
    if [ "$has_interface" = false ]; then
        log_error "No distributable Swift interfaces for Sentry"
        exit 1
    fi

    # Import declarations directly: importing the parent module here would create a cycle.
    sed 's|@import SentryHeaders;|#import <Sentry/SentryHeaders.h>|' \
        "$swift_products/Sentry-Swift.h" > "$headers_dir/Sentry-Swift.h"
    # The Swift submodule exposes Swift declarations to ObjC without reimporting them into Swift.
    cp "$SCRIPT_DIR/../Sources/Resources/SentrySPM.modulemap" "$modules_dir/module.modulemap"
}

copy_resources() {
    cp "$SCRIPT_DIR/../Sources/Resources/PrivacyInfo.xcprivacy" "$resources_dir/"
    cp -R "$SWIFT_ARCHIVE/Products/Resources"/. "$resources_dir/"
}

validate_output_location
begin_group "Prepare Sentry framework inputs"
prepared_dir="$(mktemp -d "${TMPDIR:-/tmp}/sentry-framework-inputs.XXXXXX")"
trap 'rm -rf "$prepared_dir"' EXIT
headers_dir="$prepared_dir/Headers"
modules_dir="$prepared_dir/Modules"
resources_dir="$prepared_dir/Resources"
mkdir -p "$headers_dir" "$modules_dir/Sentry.swiftmodule" "$resources_dir"

prepare_headers
prepare_modules
copy_resources

# Publish only after successful preparation. Replace generated subdirectories to remove stale inputs.
mkdir -p "$OUTPUT_DIR"
for directory in Headers Modules Resources; do
    rm -rf "${OUTPUT_DIR:?}/${directory:?}"
    mv "$prepared_dir/$directory" "$OUTPUT_DIR/$directory"
done
end_group
log_info "Prepared framework inputs: $OUTPUT_DIR"
