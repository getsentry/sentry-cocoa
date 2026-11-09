#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

usage() {
    log_info "Usage: $0"
    log_info "  -h, --help    Show this help"
    exit 1
}

[[ $# -eq 0 ]] || usage

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/sentry-framework-inputs-test.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
source_headers_dir="$work_dir/inputs/public headers"
archive_dir="$work_dir/inputs/Swift archive.xcarchive"
module_dir="$archive_dir/Products/Swift/SentrySwift.swiftmodule"
output_dir="$work_dir/prepared output"
expected_dir="$work_dir/expected output"
sdk_v10=0

assert() {
    "$@" || { log_error "Assertion failed: $*"; exit 1; }
}

prepare() {
    local expected="$1" diagnostic="${2:-}" status=0
    SDK_V10="$sdk_v10" bash "$SCRIPT_DIR/prepare-sentry-framework-inputs.sh" \
        --swift-archive "$archive_dir" \
        --headers "$source_headers_dir" \
        --output-dir "$output_dir" \
        --framework-name SentrySwift > "$work_dir/prepare.log" 2>&1 || status=$?
    if [[ "$expected" == pass ]]; then
        assert test "$status" -eq 0
    else
        assert test "$status" -ne 0
        assert grep -Fq "$diagnostic" "$work_dir/prepare.log"
    fi
}

mkdir -p "$source_headers_dir" "$module_dir" "$archive_dir/Products/Resources/SDK.bundle"
printf '// Public header\n' > "$source_headers_dir/Public.h"
printf '@import SentryHeaders;\n' > "$archive_dir/Products/Swift/SentrySwift-Swift.h"
printf 'bundle resource\n' > "$archive_dir/Products/Resources/SDK.bundle/resource.txt"
printf 'hidden resource\n' > "$archive_dir/Products/Resources/.hidden"
for interface in arm64.swiftinterface arm64.private.swiftinterface; do
    printf '%s\n' \
        '// swift-module-flags: -module-name SentrySwift' \
        'import SentryHeaders' \
        'public typealias Legacy = SentryHeaders.Type' \
        'public typealias Qualified = SentryHeaders::Type' \
        'public typealias Unchanged = OtherSentryHeaders.Type' > "$module_dir/$interface"
done
# Package interfaces and serialized artifacts must not be published or validated as public interfaces.
printf '// Not distributable\n' > "$module_dir/arm64.package.swiftinterface"
printf 'serialized module\n' > "$module_dir/arm64.swiftmodule"
cp -R "$work_dir/inputs" "$work_dir/original inputs"

mkdir -p "$expected_dir/Headers" "$expected_dir/Modules/SentrySwift.swiftmodule" "$expected_dir/Resources"
cp "$source_headers_dir/Public.h" "$expected_dir/Headers/"
printf '#import "Public.h"\n' > "$expected_dir/Headers/SentryHeaders.h"
printf '@import SentrySwift;\n' > "$expected_dir/Headers/SentrySwift-Swift.h"
for interface in arm64.swiftinterface arm64.private.swiftinterface; do
    printf '%s\n' \
        '// swift-module-flags: -module-name SentrySwift' \
        'import SentrySwift' \
        'public typealias Legacy = SentrySwift.Type' \
        'public typealias Qualified = SentrySwift::Type' \
        'public typealias Unchanged = OtherSentryHeaders.Type' > "$expected_dir/Modules/SentrySwift.swiftmodule/$interface"
done
cat > "$expected_dir/Modules/module.modulemap" <<'EOF'
framework module SentrySwift {
  umbrella header "SentryHeaders.h"
  exclude header "SentrySwift-Swift.h"
  export *
  module * { export * }
}
EOF
cp "$SCRIPT_DIR/../Sources/Resources/PrivacyInfo.xcprivacy" "$expected_dir/Resources/"
cp -R "$archive_dir/Products/Resources"/. "$expected_dir/Resources/"

prepare pass
assert diff -r "$expected_dir" "$output_dir"
log_info "PASS V9 headers, interfaces, module map, and resources"

sdk_v10=1
cp "$SCRIPT_DIR/../Sources/SentryV10Configuration/include/SentryV10Configuration.h" "$expected_dir/Headers/"
printf '#import "SentryV10Configuration.h"\n#import "Public.h"\n' > "$expected_dir/Headers/SentryHeaders.h"
prepare pass
assert diff -r "$expected_dir" "$output_dir"
log_info "PASS V10 configuration header and import order"

sdk_v10=0
rm "$expected_dir/Headers/SentryV10Configuration.h"
printf '#import "Public.h"\n' > "$expected_dir/Headers/SentryHeaders.h"
for directory in Headers Modules Resources; do
    touch "$output_dir/$directory/stale"
done
printf 'unrelated output\n' > "$output_dir/keep.txt"
cp "$output_dir/keep.txt" "$expected_dir/"
prepare pass
assert diff -r "$expected_dir" "$output_dir"
assert diff -r "$work_dir/original inputs" "$work_dir/inputs"
log_info "PASS reruns remove stale generated files but preserve inputs and unrelated output"

valid_output_dir="$output_dir"
ln -s "$source_headers_dir" "$work_dir/headers link"
ln -s "$archive_dir" "$work_dir/archive link"
ln -s "$work_dir/inputs" "$work_dir/inputs link"
for output_dir in \
    "$source_headers_dir" "$archive_dir" \
    "$source_headers_dir/missing/prepared" "$archive_dir/missing/prepared" \
    "$work_dir/inputs" \
    "$work_dir/headers link/missing/prepared" "$work_dir/archive link/missing/prepared" \
    "$work_dir/inputs link"; do
    prepare fail 'Output directory'
    assert diff -r "$work_dir/original inputs" "$work_dir/inputs"
done
log_info "PASS overlapping output paths, including symlinks, are rejected without changing inputs"

output_dir="$valid_output_dir"
printf '// swift-module-flags: -module-name WrongModule\n' > "$module_dir/arm64.swiftinterface"
prepare fail 'Swift module name does not match'
assert diff -r "$expected_dir" "$output_dir"
log_info "PASS invalid module names leave existing output unchanged"

rm "$module_dir/arm64.swiftinterface" "$module_dir/arm64.private.swiftinterface"
prepare fail 'No distributable Swift interfaces'
assert diff -r "$expected_dir" "$output_dir"
log_info "PASS package-only interfaces leave existing output unchanged"
