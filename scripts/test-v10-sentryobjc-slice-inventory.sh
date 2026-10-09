#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
WORK_DIR=""

usage() {
    log_info "Usage: $0 [--work-dir|-w PATH]"
    log_info "  --work-dir, -w: retain fixtures/logs in a new directory (optional)"
    exit 1
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        --work-dir|-w) [[ $# -ge 2 ]] || usage; WORK_DIR="$2"; shift 2 ;;
        *) usage ;;
    esac
done
if [[ -n "$WORK_DIR" ]]; then
    [[ ! -e "$WORK_DIR" ]] || { log_error "Work directory exists"; exit 1; }
    mkdir -p "$WORK_DIR"
else
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' EXIT
fi
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
XCFRAMEWORK="$WORK_DIR/wrapper with spaces.xcframework"
mkdir -p "$XCFRAMEWORK/static/CustomHeaders" "$XCFRAMEWORK/framework/SentryObjC.framework/Headers"
printf '@interface SentryObjCSDK @end\n@implementation SentryObjCSDK @end\n' > "$WORK_DIR/wrapper.m"
xcrun clang -c "$WORK_DIR/wrapper.m" -o "$WORK_DIR/wrapper.o" 2> "$WORK_DIR/compile.log"
xcrun libtool -static -o "$XCFRAMEWORK/static/libSentryObjC.a" "$WORK_DIR/wrapper.o"
xcrun clang -dynamiclib "$WORK_DIR/wrapper.o" -lobjc -o "$XCFRAMEWORK/framework/SentryObjC.framework/SentryObjC"
printf '// SDK wrapper header\n' > "$XCFRAMEWORK/static/CustomHeaders/SentryObjC.h"
printf '// SDK wrapper header\n' > "$XCFRAMEWORK/framework/SentryObjC.framework/Headers/SentryObjC.h"
jq -n '{AvailableLibraries: [
    {LibraryIdentifier: "static", LibraryPath: "libSentryObjC.a", HeadersPath: "CustomHeaders"},
    {LibraryIdentifier: "framework", LibraryPath: "SentryObjC.framework"}
]}' > "$WORK_DIR/info.json"

make_plist() {
    plutil -convert "$1" -o "$XCFRAMEWORK/Info.plist" "$WORK_DIR/info.json"
}
check() {
    local name="$1" expected="$2" diagnostic="${3:-}" status=0
    bash "$SCRIPT_DIR/verify-v10-sentrycrash-sentryobjc.sh" --xcframework-path "$XCFRAMEWORK" \
        > "$WORK_DIR/$name.log" 2>&1 || status=$?
    if [[ "$expected" == pass ]]; then
        [[ "$status" == 0 ]] || { log_error "$name failed; see $WORK_DIR/$name.log"; exit 1; }
        grep -q '2 V10 SentryObjC XCFramework slice' "$WORK_DIR/$name.log"
    else
        [[ "$status" != 0 ]] || { log_error "$name unexpectedly passed"; exit 1; }
        [[ -z "$diagnostic" ]] || grep -Fq "$diagnostic" "$WORK_DIR/$name.log"
    fi
    log_info "PASS $name"
}
make_plist xml1
check xml-static-and-framework pass
make_plist binary1
check binary-static-and-framework pass
cp "$WORK_DIR/info.json" "$WORK_DIR/valid-info.json"
jq '.AvailableLibraries[0].LibraryPath = "../outside.a"' "$WORK_DIR/valid-info.json" > "$WORK_DIR/info.json"
make_plist xml1
check traversal fail 'Invalid slice paths'
printf '{"AvailableLibraries": []}\n' > "$WORK_DIR/info.json"
make_plist binary1
check empty-inventory fail 'Missing library slices'
jq 'del(.AvailableLibraries[0].LibraryIdentifier)' "$WORK_DIR/valid-info.json" > "$WORK_DIR/info.json"
make_plist xml1
check missing-identifier fail
jq '.AvailableLibraries[0].HeadersPath = false' "$WORK_DIR/valid-info.json" > "$WORK_DIR/info.json"
make_plist xml1
check invalid-headers-path fail
cp "$WORK_DIR/valid-info.json" "$WORK_DIR/info.json"
make_plist binary1
mv "$XCFRAMEWORK/static/libSentryObjC.a" "$WORK_DIR/library.backup"
check missing-binary fail 'slice binary is missing'
mv "$WORK_DIR/library.backup" "$XCFRAMEWORK/static/libSentryObjC.a"
printf 'int sentrycrash_install(void) { return 1; }\n' > "$WORK_DIR/recorder.c"
xcrun clang -c "$WORK_DIR/recorder.c" -o "$WORK_DIR/recorder.o"
xcrun libtool -static -o "$XCFRAMEWORK/static/libSentryObjC.a" "$WORK_DIR/wrapper.o" "$WORK_DIR/recorder.o"
check recorder-symbol fail 'contains recorder symbol'
log_info "Slice inventory and artifact rejection controls passed; logs and test files: $WORK_DIR"
