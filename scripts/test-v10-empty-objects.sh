#!/bin/bash
set -euo pipefail

# Real Mach-O controls for the temporary development bridge to V10 separation.
# Compiler, nm, otool and relocatable linking are real, not stubbed.
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
    [[ ! -e "$WORK_DIR" ]] || { log_error "Work directory exists: $WORK_DIR"; exit 1; }
    mkdir -p "$WORK_DIR"
else
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' EXIT
fi

WORK_DIR="$(cd "$WORK_DIR" && pwd)"
REPOSITORY="$WORK_DIR/repository with spaces"
BUILD="$WORK_DIR/build with spaces"
BUILD_LOG="$WORK_DIR/build.log"
HELPER="$WORK_DIR/verify-empty"
SOURCE="$REPOSITORY/Sources/SentryCrash/Recording/Probe.c"
OBJECT="$BUILD/Probe.c.o"
COMPILER="$(xcrun --find clang)"
COMPILE_FLAGS=(-DSDK_V10=1 -c)
COUNT=0

mkdir -p "$(dirname "$SOURCE")" "$BUILD"
printf '#if !SDK_V10\nint arbitrary_function(void) { return 1; }\n#endif\n' > "$SOURCE"
swiftc "$SCRIPT_DIR/verify-v10-empty-objects.swift" -o "$HELPER"

write_build_log() {
    jq -nr --args '$ARGS.positional | @sh' -- "$@" > "$BUILD_LOG"
    printf '\nBuild complete! (fixture)\n' >> "$BUILD_LOG"
}

compile_command() {
    if ! "$@" > "$WORK_DIR/compile.log" 2>&1; then
        log_error "Fixture compilation failed; see $WORK_DIR/compile.log"
        exit 1
    fi

    write_build_log "$@"
}

compile_fixture() {
    if [[ $# -gt 0 ]]; then printf '%s\n' "$1" > "$SOURCE"; fi

    compile_command "$COMPILER" "${COMPILE_FLAGS[@]}" "$SOURCE" -o "$OBJECT"
}

check() {
    local name="$1" expected="$2" diagnostic="${3:-}" status=0
    local executable=("$HELPER")
    if [[ "${4:-}" == wrapper ]]; then
        executable=(bash "$SCRIPT_DIR/verify-v10-sentrycrash-objects.sh")
    fi

    "${executable[@]}" --build-path "$BUILD" --build-log "$BUILD_LOG" --source-root "$REPOSITORY" \
        > "$WORK_DIR/$name.log" 2>&1 || status=$?

    if [[ "$expected" == pass ]]; then
        [[ "$status" == 0 ]] || { log_error "$name failed; see $WORK_DIR/$name.log"; exit 1; }
    else
        [[ "$status" != 0 ]] || { log_error "$name unexpectedly passed"; exit 1; }
    fi

    if [[ -n "$diagnostic" ]] && ! grep -Fq "$diagnostic" "$WORK_DIR/$name.log"; then
        log_error "$name failed for the wrong reason; see $WORK_DIR/$name.log"
        exit 1
    fi

    COUNT=$((COUNT + 1))
    log_info "PASS $name"
}

replace_completion() {
    sed "s/Build complete!/$1/" "$BUILD_LOG" > "$WORK_DIR/replaced.log"
    mv "$WORK_DIR/replaced.log" "$BUILD_LOG"
}

test_aggregate() {
    local list="$WORK_DIR/inputs.LinkFileList" aggregate="$BUILD/Aggregate.o"
    local command=("$COMPILER" -r -nostdlib -filelist "$list" -o "$aggregate")

    printf '%s\n' "$OBJECT" > "$list"
    "${command[@]}" > "$WORK_DIR/link.log" 2>&1
    cp "$BUILD_LOG" "$WORK_DIR/complete-aggregate.log"
    jq -nr --args '$ARGS.positional | @sh' -- "${command[@]}" >> "$WORK_DIR/complete-aggregate.log"
    printf '\nBuild complete!\n' >> "$WORK_DIR/complete-aggregate.log"
    cp "$WORK_DIR/complete-aggregate.log" "$BUILD_LOG"
    check accounted-aggregate pass

    printf '%s\n' "$BUILD/Unknown.o" > "$list"
    check unknown-aggregate-input fail 'aggregate inputs'

    printf '%s\n' "$OBJECT" > "$list"
    cp "$OBJECT" "$WORK_DIR/source.backup.o"
    compile_fixture 'int arbitrary_aggregate_implementation(void) { return 1; }'
    "${command[@]}" > "$WORK_DIR/link.log" 2>&1
    cp "$WORK_DIR/source.backup.o" "$OBJECT"
    cp "$WORK_DIR/complete-aggregate.log" "$BUILD_LOG"
    check aggregate-implementation-injection fail 'Aggregate implementation differs'

    rm "$aggregate"
}

test_implementations() {
    local names=(guard-loss data-only local-data initializer fake-metadata-name anonymous-data unexpected-autolink)
    local code=(
        'int arbitrary_function(void) { return 1; }'
        'int arbitrary_data = 17;'
        'static int arbitrary_data __attribute__((used)) = 17;'
        '__attribute__((constructor)) static void init(void) {}'
        'int __swift_FORCE_LOAD_fake = 17;'
        '__asm__(".section __DATA,__data\n.byte 17\n");'
        '__asm__(".linker_option \"-lUnexpectedRecorder\"\n");'
    )
    local index
    for index in "${!names[@]}"; do
        compile_fixture "${code[$index]}"
        check "${names[$index]}" fail implementation
    done

    printf '@interface ArbitraryClass @end\n@implementation ArbitraryClass @end\n' > "$SOURCE"

    compile_command "$COMPILER" -x objective-c -DSDK_V10=1 -c "$SOURCE" -o "$OBJECT"
    check objc-class fail implementation
}

test_missing_build_information() {
    compile_fixture '/* empty */'
    compile_command "$COMPILER" -DSDK_V10=0 -c "$SOURCE" -o "$OBJECT"
    check wrong-flag fail 'V10 flag'

    compile_command "$COMPILER" -DSDK_V10=1 -U SDK_V10 -c "$SOURCE" -o "$OBJECT"
    check later-undefine fail 'Conflicting V10 flag'

    compile_command "$COMPILER" -MMD -MF "$WORK_DIR/operand.d" -MT -DSDK_V10=1 -c "$SOURCE" -o "$OBJECT"
    check define-is-dependency-target fail 'Missing selected V10 flag'
    compile_command "$COMPILER" -DSDK_V10=1 -MMD -MF "$WORK_DIR/operand.d" -MT -USDK_V10 -c "$SOURCE" -o "$OBJECT"
    check undefine-is-dependency-target pass
    compile_command "$COMPILER" -D SDK_V10=1 -c "$SOURCE" -o "$OBJECT"
    check clang-split-define pass
    compile_command "$COMPILER" -DSDK_V10 -c "$SOURCE" -o "$OBJECT"
    check clang-implicit-one-define pass
    write_build_log "$COMPILER" -c "$SOURCE" -o "$OBJECT" -- -DSDK_V10=1
    check define-after-options-end fail 'Missing selected V10 flag'
    compile_fixture
    write_build_log "$WORK_DIR/output.scan" -- "$COMPILER" "${COMPILE_FLAGS[@]}" "$SOURCE" -o "$OBJECT"
    check xcode-scanner-command-prefix pass

    compile_fixture
    replace_completion 'Build interrupted!'
    check incomplete-build fail 'completed build'

    compile_fixture
    rm "$OBJECT"
    check missing-output fail 'Missing completed output'

    compile_fixture
    mkdir -p "$BUILD/SentryCrashV9.build"
    cp "$OBJECT" "$BUILD/SentryCrashV9.build/Unknown.o"
    check unknown-object fail 'Unaccounted legacy object'

    rm "$BUILD/SentryCrashV9.build/Unknown.o"
    printf 'Build complete! (fixture)\n' > "$BUILD_LOG"
    check missing-commands fail 'No compiler commands producing object files'

    write_build_log "$COMPILER" "${COMPILE_FLAGS[@]}" "$REPOSITORY/Sources/SentryCrash/Recording/Unknown.c" -o "$OBJECT"
    check unknown-source fail 'Unknown legacy source'

    compile_fixture
    cp "$OBJECT" "$BUILD/arbitrary-output.o"
    check unknown-nonlegacy-name fail 'Unaccounted compiler object'

    rm "$BUILD/arbitrary-output.o"
    write_build_log "$COMPILER" @/nonexistent/flags.rsp "${COMPILE_FLAGS[@]}" "$SOURCE" -o "$OBJECT"
    check missing-response fail 'response file'

    compile_fixture
    printf '** BUILD FAILED **\n' >> "$BUILD_LOG"
    check failed-after-success fail 'Failed/incomplete build'
}

write_output_map() {
    jq -n --arg source "$1" --arg key "$2" --arg object "$OBJECT" '{($source): {($key): $object}}' \
        > "$WORK_DIR/output-file-map.json"
}

test_swift() {
    rm "$OBJECT"
    SOURCE="$REPOSITORY/Sources/SentryCrashV9Swift/Probe.swift"
    OBJECT="$BUILD/Probe.swift.o"
    COMPILER="$(xcrun --find swiftc)"
    mkdir -p "$(dirname "$SOURCE")"
    COMPILE_FLAGS=(-sdk "$(xcrun --sdk macosx --show-sdk-path)" -parse-as-library -DSDK_V10 \
        -module-name SentryCrashV9Swift -emit-object)
    compile_fixture $'#if !SDK_V10\nfunc arbitraryFunction() {}\n#endif\n'
    check swift-guarded-empty pass

    compile_command "$COMPILER" "${COMPILE_FLAGS[@]}" -Xcc -U -Xcc SDK_V10 "$SOURCE" -o "$OBJECT"
    check swift-forwarded-split-undefine fail 'Conflicting V10 flag'
    compile_command "$COMPILER" "${COMPILE_FLAGS[@]}" -Xcc -USDK_V10 "$SOURCE" -o "$OBJECT"
    check swift-forwarded-joined-undefine fail 'Conflicting V10 flag'
    compile_command "$COMPILER" "${COMPILE_FLAGS[@]}" -Xcc -D -Xcc SDK_V10=1 "$SOURCE" -o "$OBJECT"
    check swift-forwarded-split-define pass
    compile_command "$COMPILER" "${COMPILE_FLAGS[@]}" -Xcc -D -Xcc SDK_V10=0 "$SOURCE" -o "$OBJECT"
    check swift-forwarded-wrong-value fail 'Conflicting V10 flag'
    compile_command "$COMPILER" "${COMPILE_FLAGS[@]}" -Xcc -MT -Xcc -USDK_V10 "$SOURCE" -o "$OBJECT"
    check swift-forwarded-undefine-is-operand pass
    compile_command "$COMPILER" -sdk "$(xcrun --sdk macosx --show-sdk-path)" -parse-as-library \
        -module-name SentryCrashV9Swift -emit-object -Xcc -DSDK_V10=1 "$SOURCE" -o "$OBJECT"
    check swift-importer-define-is-not-swift-define fail 'Missing selected V10 flag'
    compile_fixture

    write_output_map "$SOURCE" object
    COMPILE_FLAGS+=(-output-file-map "$WORK_DIR/output-file-map.json")
    compile_fixture
    check swift-output-map pass

    write_output_map "$SOURCE" wrong
    check missing-map-object fail 'Missing source object'

    write_output_map Unknown.swift object
    check map-source-drift fail 'source-list disagreement'

    write_output_map "$SOURCE" object
    compile_fixture 'func arbitraryFunction() {}'
    check swift-guard-loss fail implementation
}

test_header_reference() {
    rm "$OBJECT"
    SOURCE="$REPOSITORY/Sources/Sentry/SentryCrashDefaultMachineContextWrapper.m"
    OBJECT="$BUILD/SentryCrashDefaultMachineContextWrapper.m.o"
    COMPILER="$(xcrun --find clang)"
    mkdir -p "$(dirname "$SOURCE")"
    local header
    header="$(dirname "$SOURCE")/SentryDefines.h"
    printf 'static const int SDK_HEADER_CONSTANT __attribute__((used)) = 3;\n' > "$header"
    COMPILE_FLAGS=(-I "$(dirname "$SOURCE")" -DSDK_V10=1 -c)
    compile_fixture '#import "SentryDefines.h"'
    check header-only-constants pass

    compile_fixture $'#import "SentryDefines.h"\nstatic int arbitrary_data __attribute__((used)) = 17;\n'
    check header-exception-data-injection fail 'differs from SDK header-only reference'

    printf 'static int header_implementation(void) __attribute__((used));\nstatic int header_implementation(void) { return 17; }\n' > "$header"
    compile_fixture '#import "SentryDefines.h"'
    check header-reference-code-injection fail 'Header-only reference emits implementation'
}

test_real_guard_loss() {
    rm "$OBJECT"

    local repository_root
    repository_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    local relative=Sources/SentryCrash/Recording/Tools/SentryCrashString.c
    SOURCE="$REPOSITORY/$relative"
    OBJECT="$BUILD/SentryCrashString.c.o"

    mkdir -p "$(dirname "$SOURCE")"
    cp "$repository_root/$relative" "$SOURCE"
    COMPILE_FLAGS=(-isysroot "$(xcrun --sdk macosx --show-sdk-path)" -DSDK_V10=1 \
        -I "$repository_root/Sources/Sentry/include" -I "$repository_root/Sources/SentryCrash/Recording/Tools" -c)
    compile_fixture
    check real-recorder-guarded pass

    sed 's/#if !SDK_V10/#if 1/g' "$repository_root/$relative" > "$SOURCE"
    compile_fixture
    check real-recorder-guard-loss fail implementation
}

test_section_inventory() {
    local proxy="$WORK_DIR/section-tools" original_path="$PATH"
    mkdir -p "$proxy"
    # Keep objects real; change only the section counts reported by otool.
    printf '#!/bin/bash\nset -euo pipefail\n' > "$proxy/xcrun"
    printf 'REAL_XCRUN=%q\n' "$(command -v xcrun)" >> "$proxy/xcrun"
    cat >> "$proxy/xcrun" <<'SH'
if [[ "${1:-}" == otool && "${2:-}" == -l ]]; then
    "$REAL_XCRUN" "$@" | awk -v mode="$SECTION_TEST_MODE" '
      $1 == "nsects" && !changed {
        changed = 1
        if (mode == "missing-count") next
        if (mode == "wrong-count") { $2 += 1; print; next }
        if (mode == "redistributed") { count = $2; $2 = 0; print; next }
      }
      mode == "malformed-section" && $1 == "sectname" { next }
      { print }
      END {
        if (mode == "zero-segment" || mode == "redistributed") {
          print "Load command 999"
          print "      cmd LC_SEGMENT_64"
          print "   nsects " (mode == "redistributed" ? count : 0)
        }
      }'
else
    exec "$REAL_XCRUN" "$@"
fi
SH
    chmod +x "$proxy/xcrun"
    export PATH="$proxy:$PATH"
    export SECTION_TEST_MODE=zero-segment
    check zero-section-segment pass
    export SECTION_TEST_MODE=wrong-count
    check section-count-mismatch fail 'Section inventory mismatch'
    export SECTION_TEST_MODE=missing-count
    check missing-section-count fail 'Missing/invalid segment section count'
    export SECTION_TEST_MODE=malformed-section
    check unparsed-section fail 'Section inventory mismatch'
    export SECTION_TEST_MODE=redistributed
    check per-segment-count-mismatch fail 'Section inventory mismatch'
    export PATH="$original_path"
    unset SECTION_TEST_MODE
}

test_file_search_failures() {
    local blocked="$REPOSITORY/Sources/SentryCrash/unreadable"
    mkdir -p "$blocked"
    printf '/* hidden source */\n' > "$blocked/Hidden.c"
    chmod 000 "$blocked"
    check unreadable-source-directory fail 'Cannot enumerate'
    chmod 700 "$blocked"
    rm -rf "$blocked"

    blocked="$BUILD/unreadable"
    mkdir -p "$blocked"
    cp "$OBJECT" "$blocked/Hidden.o"
    chmod 000 "$blocked"
    check unreadable-object-directory fail 'Cannot enumerate'
    chmod 700 "$blocked"
    rm -rf "$blocked"

    ln -s "$BUILD/nonexistent.o" "$BUILD/Broken.o"
    check broken-object-symlink fail 'Cannot read file metadata'
    rm "$BUILD/Broken.o"
}

test_audit_coverage() {
    local links="$WORK_DIR/output-links" hidden="$BUILD/Hidden.bin"
    mkdir -p "$links"
    cp "$OBJECT" "$hidden"
    ln -s "$hidden" "$links/Hidden.o"
    ln -s "$links" "$BUILD/linked-output"
    cp "$BUILD_LOG" "$WORK_DIR/coverage-original.log"
    # This logged output resolves to a real file inside the build directory, but
    # enumeration does not follow the directory symlink and the target has no .o suffix.
    jq -nr --args '$ARGS.positional | @sh' -- "$COMPILER" "${COMPILE_FLAGS[@]}" \
        "$SOURCE" -o "$BUILD/linked-output/Hidden.o" >> "$BUILD_LOG"
    check unvisited-observed-object fail 'Legacy object coverage mismatch'
    cp "$WORK_DIR/coverage-original.log" "$BUILD_LOG"
    rm "$BUILD/linked-output" "$links/Hidden.o" "$hidden"
    rmdir "$links"
}

compile_fixture
check guarded-empty pass '' wrapper

test_audit_coverage
test_file_search_failures
test_section_inventory

replace_completion "Build of target: 'SentrySwift' complete!"
check completed-target-build pass

compile_fixture

test_aggregate
test_implementations
test_missing_build_information
test_swift
test_header_reference
test_real_guard_loss

[[ "$COUNT" == 54 ]] || { log_error "Missing expected control coverage: $COUNT/54"; exit 1; }
log_info "$COUNT real V10 separation empty-object controls passed; logs and test files: $WORK_DIR"
