#!/bin/bash
# Prepare the main SDK's headers, Swift interfaces, and resources for framework packaging.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

SWIFT_ARCHIVE=""
HEADERS_DIR=""
OUTPUT_DIR=""
FRAMEWORK_NAME=""

usage() {
    log_info "Usage: $0"
    log_info "  -a, --swift-archive <path>    Source archive containing Swift artifacts (required)"
    log_info "  -H, --headers <path>          Original SDK public headers directory (required)"
    log_info "  -o, --output-dir <path>       Staging directory for Headers, Modules, Resources (required)"
    log_info "  -n, --framework-name <name>   Compiled Swift module name (required)"
    log_info "Use the same SDK_V10 environment setting as the source archive."
    exit 1
}

while [[ $# -gt 0 ]]; do
    if [[ "$1" != -h && "$1" != --help ]] && [[ $# -lt 2 || "$2" == --* ]]; then
        log_error "Missing value for $1"
        usage
    fi
    case $1 in
        -a|--swift-archive) SWIFT_ARCHIVE="$2"; shift 2 ;;
        -H|--headers) HEADERS_DIR="$2"; shift 2 ;;
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -n|--framework-name) FRAMEWORK_NAME="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown argument: $1"; usage ;;
    esac
done

require_argument() {
    if [ -z "$2" ]; then
        log_error "$1 is required"
        usage
    fi
}

require_argument --swift-archive "$SWIFT_ARCHIVE"
require_argument --headers "$HEADERS_DIR"
require_argument --output-dir "$OUTPUT_DIR"
require_argument --framework-name "$FRAMEWORK_NAME"

if [[ ! "$FRAMEWORK_NAME" =~ ^[A-Za-z_][A-Za-z_0-9]*$ ]]; then
    log_error "Invalid framework module name: $FRAMEWORK_NAME"
    exit 1
fi
if [ ! -d "$HEADERS_DIR" ]; then
    log_error "Headers directory not found: $HEADERS_DIR"
    exit 1
fi
swift_products="$SWIFT_ARCHIVE/Products/Swift"
if [ ! -d "$swift_products/$FRAMEWORK_NAME.swiftmodule" ] || \
    [ ! -f "$swift_products/$FRAMEWORK_NAME-Swift.h" ]; then
    log_error "Missing Swift artifacts for $FRAMEWORK_NAME in $SWIFT_ARCHIVE"
    exit 1
fi

# Validate before preparing or replacing any output. Never rename the compiled Swift module.
interfaces=()
for interface in "$swift_products/$FRAMEWORK_NAME.swiftmodule"/*.swiftinterface; do
    [ -f "$interface" ] || continue
    [[ "$interface" != *.package.swiftinterface ]] || continue
    if ! grep -Eq -- "-module-name $FRAMEWORK_NAME( |$)" "$interface"; then
        log_error "Swift module name does not match $FRAMEWORK_NAME: $interface"
        exit 1
    fi
    interfaces+=( "$interface" )
done
if [ "${#interfaces[@]}" -eq 0 ]; then
    log_error "No distributable Swift interfaces for $FRAMEWORK_NAME"
    exit 1
fi

# Resolve the nearest existing output ancestor without creating directories inside an input.
output_ancestor="$OUTPUT_DIR"
while [ ! -e "$output_ancestor" ]; do
    output_ancestor="$(dirname "$output_ancestor")"
done
output_ancestor="$(cd "$output_ancestor" && pwd -P)"
for input_dir in "$HEADERS_DIR" "$SWIFT_ARCHIVE"; do
    input_dir="$(cd "$input_dir" && pwd -P)"
    if [[ "$output_ancestor/" == "$input_dir/"* ]] || \
        { [ -d "$OUTPUT_DIR" ] && [[ "$input_dir/" == "$output_ancestor/"* ]]; }; then
        log_error "Output directory must not overlap the source headers or archive: $OUTPUT_DIR"
        exit 1
    fi
done

begin_group "Prepare $FRAMEWORK_NAME framework inputs"
prepared_dir="$(mktemp -d "${TMPDIR:-/tmp}/sentry-framework-inputs.XXXXXX")"
trap 'rm -rf "$prepared_dir"' EXIT
headers_dir="$prepared_dir/Headers"
modules_dir="$prepared_dir/Modules"
resources_dir="$prepared_dir/Resources"
mkdir -p "$headers_dir" "$modules_dir" "$resources_dir"

# Combine the public Clang declarations with the Swift overlay, like an Xcode-built framework.
umbrella_header="SentryHeaders.h"
# Reuse the source list for the umbrella, excluding headers generated during preparation.
public_headers=("$HEADERS_DIR"/*.h)
for header in "${public_headers[@]}"; do
    sed -E \
        -e 's/(#[[:space:]]*(import|include))[[:space:]]+<([A-Za-z0-9_]+\.h)>/\1 "\3"/' \
        -e 's/(#[[:space:]]*(import|include))[[:space:]]+SENTRY_HEADER\(([A-Za-z0-9_]+)\)/\1 "\3.h"/' \
        "$header" > "$headers_dir/${header##*/}"
done
{
    # Match the archive's generation without requiring consumer compiler flags.
    if [ "${SDK_V10:-0}" = 1 ]; then
        cp "$SCRIPT_DIR/../Sources/SentryV10Configuration/include/SentryV10Configuration.h" "$headers_dir/"
        printf '#import "SentryV10Configuration.h"\n'
    fi
    for header in "${public_headers[@]}"; do
        printf '#import "%s"\n' "${header##*/}"
    done
} > "$headers_dir/$umbrella_header"

# Keep public and private interfaces, not serialized modules with producer-only search paths.
module_dir="$modules_dir/$FRAMEWORK_NAME.swiftmodule"
mkdir -p "$module_dir"
for interface in "${interfaces[@]}"; do
    # Swift 6.4 qualifies module types with ::; preserve either compiler spelling.
    sed -E "s/(^|[^[:alnum:]_])SentryHeaders([.]|::|$)/\1$FRAMEWORK_NAME\2/g" \
        "$interface" > "$module_dir/${interface##*/}"
done
sed "s/@import SentryHeaders;/@import $FRAMEWORK_NAME;/" \
    "$swift_products/$FRAMEWORK_NAME-Swift.h" > "$headers_dir/$FRAMEWORK_NAME-Swift.h"

# The Swift header imports this module, so exclude it rather than adding it to the umbrella.
cat > "$modules_dir/module.modulemap" <<EOF
framework module $FRAMEWORK_NAME {
  umbrella header "$umbrella_header"
  exclude header "$FRAMEWORK_NAME-Swift.h"
  export *
  module * { export * }
}
EOF

cp "$SCRIPT_DIR/../Sources/Resources/PrivacyInfo.xcprivacy" "$resources_dir/"
cp -R "$SWIFT_ARCHIVE/Products/Resources"/. "$resources_dir/"

# Replace only generated subdirectories, so reruns do not retain stale interfaces or V10 headers.
mkdir -p "$OUTPUT_DIR"
for directory in Headers Modules Resources; do
    rm -rf "${OUTPUT_DIR:?}/${directory:?}"
    mv "$prepared_dir/$directory" "$OUTPUT_DIR/$directory"
done
end_group
log_info "Prepared framework inputs: $OUTPUT_DIR"
