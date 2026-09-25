#!/bin/bash
# This file has been generated using agentic tooling.
# The purpose of this file is to support during developer tooling and iterative experimentation,
# not a human-reviewed, verified source of correctness.
# Take its assumptions and coverage with a grain of salt, and independently validate important behavior.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/../symbolicate.sh"
for tool in jq xcrun sentry-cli; do
    command -v "$tool" >/dev/null || {
        echo "Required test tool not found: $tool" >&2
        exit 1
    }
done
export REAL_LEGACY_CLI FIXTURE_DIR FIXTURE_UUID FIXTURE_ARCH
REAL_LEGACY_CLI="$(command -v sentry-cli)"
JQ="$(command -v jq)"
umask 077
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/metrickit-test.XXXXXX")"
CURRENT_CASE=setup
TEST_COUNT=0
cleanup() {
    local status=$?
    if [[ "$status" = 0 ]]; then
        rm -rf "$FIXTURE_DIR"
    else
        echo "FAIL: $CURRENT_CASE. Test artifacts retained at $FIXTURE_DIR" >&2
    fi
}
trap cleanup EXIT

# Background: isolated tools and generated symbols
# Given real Mach-O/dSYM fixtures, a private HOME, and mocked Sentry API calls
# And a legacy CLI wrapper that rejects unbounded filesystem discovery
export HOME="$FIXTURE_DIR/home with spaces"
mkdir -p "$HOME" "$FIXTURE_DIR/bin" "$FIXTURE_DIR/api-bin" "$FIXTURE_DIR/empty"
cp "$TEST_DIR/sentry-cli-stub.sh" "$FIXTURE_DIR/bin/sentry-cli"
cp "$TEST_DIR/sentry-stub.sh" "$FIXTURE_DIR/api-bin/sentry"
chmod +x "$FIXTURE_DIR/bin/sentry-cli" "$FIXTURE_DIR/api-bin/sentry"
ln -s "$JQ" "$FIXTURE_DIR/bin/jq"
OFFLINE_PATH="$FIXTURE_DIR/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$FIXTURE_DIR/api-bin:$OFFLINE_PATH"
unset SENTRY_ORG SENTRY_PROJECT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}
assert_absent() {
    if grep -q "$@"; then fail "Unexpected log content: $1"; fi
}
expect_failure() {
    local name="$1"
    shift
    if "$@" >"$FIXTURE_DIR/$name.log" 2>&1; then fail "Expected failure: $name"; fi
}
count_resolved() {
    jq '[.callStackTree.callStacks[].callStackRootFrames[] | recurse(.subFrames[]?) | select(.symbolication.function? != null)] | length' "$1"
}
assert_preserved() {
    jq 'walk(if type == "object" then del(.symbolication) else . end)' "$2" >"$FIXTURE_DIR/stripped.json"
    cmp "$1" "$FIXTURE_DIR/stripped.json"
}
assert_symbolicated() {
    jq -e '.callStackTree.callStacks[0].callStackRootFrames[0] |
        .symbolication.function == "metrickit_fixture" and
        (.symbolication.file | endswith("source files/fixture.c")) and
        .symbolication.line > 0 and (.address | tostring) == "18446744073709551610" and
        .subFrames[0].symbolication.function == "metrickit_fixture" and
        all(.subFrames[1:][]; has("symbolication") | not)
    ' "$1" >/dev/null
    assert_preserved "$FIXTURE_DIR/original.json" "$1"
}
build_fixture() {
    local directory="$1" uuid address base offset
    mkdir -p "$directory/source files"
    cp "$TEST_DIR/fixture.c" "$directory/source files/fixture.c"
    xcrun clang -g -O0 -c "$directory/source files/fixture.c" -o "$directory/fixture.o"
    xcrun clang -g -o "$directory/app" "$directory/fixture.o"
    xcrun dsymutil "$directory/app"
    uuid="$(xcrun dwarfdump --uuid "$directory/app" | awk '{print tolower($2)}')"
    address="$(xcrun nm -n "$directory/app" | awk '$3 == "_metrickit_fixture" {print $1}')"
    base="$(xcrun otool -l "$directory/app" | awk '$1 == "segname" && $2 == "__TEXT" {text=1} text && $1=="vmaddr" {print $2; exit}')"
    offset="$((16#$address - base))"
    jq -n --arg uuid "$uuid" --argjson offset "$offset" '
        {binaryUUID:($uuid|ascii_upcase),binaryName:"app",sampleCount:7,
         address:18446744073709551610,offsetIntoBinaryTextSegment:$offset} as $frame |
        {diagnosticMetaData:{platformArchitecture:"arm64e",custom:"preserve me"},callStackTree:{
          callStackPerThread:true,callStacks:[{threadAttributed:true,callStackRootFrames:[
            ($frame + {sampleCount:35,subFrames:[($frame + {address:123456}),
              ($frame + {offsetIntoBinaryTextSegment:0}),
              ($frame + {offsetIntoBinaryTextSegment:9007199254740000}),
              ($frame + {binaryUUID:"11111111-1111-1111-1111-111111111111"}),
              ($frame + {offsetIntoBinaryTextSegment:($offset + 0.5)})]})]}]}}
    ' >"$directory/report.json"
}
build_fixture "$FIXTURE_DIR"
build_fixture "$FIXTURE_DIR/system"
FIXTURE_UUID="$(xcrun dwarfdump --uuid "$FIXTURE_DIR/app" | awk '{print tolower($2)}')"
FIXTURE_ARCH="$(xcrun dwarfdump --uuid "$FIXTURE_DIR/app" | awk '{gsub(/[()]/,"",$3); print $3}')"
cp "$FIXTURE_DIR/report.json" "$FIXTURE_DIR/original.json"
SYMBOLS="$HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone13,2 27.0 (24A437)/arm64e/Symbols"
mkdir -p "$SYMBOLS"
cp "$FIXTURE_DIR/system/app.dSYM/Contents/Resources/DWARF/app" "$SYMBOLS/SystemImage"
jq -n --slurpfile app "$FIXTURE_DIR/report.json" --slurpfile system "$FIXTURE_DIR/system/report.json" '
    $app[0] | .diagnosticMetaData += {deviceType:"iPhone13,2",osVersion:"iPhone OS 27.0 (24A437)",platformArchitecture:"arm64e"} |
    .callStackTree.callStacks += $system[0].callStackTree.callStacks
' >"$FIXTURE_DIR/device-report.json"

remote() {
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -l "$FIXTURE_DIR/empty" "$@"
}
run_case() {
    CURRENT_CASE="$1"
    export PATH="$FIXTURE_DIR/api-bin:$OFFLINE_PATH"
    : >"$FIXTURE_DIR/calls"
    : >"$FIXTURE_DIR/legacy-calls"
    "$1"
    TEST_COUNT=$((TEST_COUNT + 1))
}

# Scenario: resolve uploaded symbols without changing original report data
# Given matching DWARF, symbol-table-only, and wrong-architecture API candidates
# When the report is symbolicated with remote fallback
# Then matching DWARF supplies function/source information and original data survives
# And zero, fractional, unknown-image, and unresolvable offsets stay unresolved
test_remote_resolution() {
    remote -o "$FIXTURE_DIR/remote.json" -c "$FIXTURE_DIR/remote-cache" >"$FIXTURE_DIR/remote.log" 2>&1
    assert_symbolicated "$FIXTURE_DIR/remote.json"
}

# Scenario: reuse validated downloaded symbols
# Given two runs for the same report and cache directory
# When the second run resolves the same image
# Then it reuses the cached file without another download and produces identical JSON
test_cache_reuse() {
    remote -o "$FIXTURE_DIR/cache-first.json" -c "$FIXTURE_DIR/cache" >"$FIXTURE_DIR/cache-first.log" 2>&1
    remote -o "$FIXTURE_DIR/cache-second.json" -c "$FIXTURE_DIR/cache" -v >"$FIXTURE_DIR/cache-second.log" 2>&1
    cmp "$FIXTURE_DIR/cache-first.json" "$FIXTURE_DIR/cache-second.json"
    grep -q 'Cache hit' "$FIXTURE_DIR/cache-second.log"
    [[ "$(grep -c 'id=42' "$FIXTURE_DIR/calls")" = 1 ]]
    [[ "$(find "$FIXTURE_DIR/cache" -name '*.macho' | wc -l | tr -d ' ')" = 1 ]]
}

# Scenario: report progress separately from normal output
# Given a report requiring a remote download
# When verbose logging is enabled
# Then stderr identifies each stage and stdout contains no debug messages
test_verbose_progress() {
    local message
    remote -o "$FIXTURE_DIR/verbose.json" -c "$FIXTURE_DIR/verbose-cache" -v >"$FIXTURE_DIR/verbose.out" 2>"$FIXTURE_DIR/verbose.log"
    for message in 'Falling back to sentry api' 'Looking up uploaded symbols' 'Lookup finished' 'Cache miss' 'Download finished' 'Cached validated symbols' 'Running atos' 'atos finished' 'Writing output' 'Run finished'; do
        grep -q "$message" "$FIXTURE_DIR/verbose.log" || fail "Missing progress: $message"
    done
    assert_absent '\[debug\]' "$FIXTURE_DIR/verbose.out"
    assert_symbolicated "$FIXTURE_DIR/verbose.json"
}

# Scenario: refuse unsafe output paths and malformed arguments
# Given an existing output, the original input, or a symlink to the input
# When any is selected as output, or required CLI arguments are malformed
# Then the command fails without modifying the original report
test_output_and_argument_validation() {
    cp "$FIXTURE_DIR/report.json" "$FIXTURE_DIR/report.symbolicated.json"
    expect_failure existing remote
    expect_failure input remote -o "$FIXTURE_DIR/report.json"
    ln -s "$FIXTURE_DIR/report.json" "$FIXTURE_DIR/output-link.json"
    expect_failure symlink remote -o "$FIXTURE_DIR/output-link.json"
    expect_failure missing-value /bin/bash "$SCRIPT" --report
    expect_failure unknown-option /bin/bash "$SCRIPT" --bogus
    cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/report.json"
    cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/report.symbolicated.json"
}

# Scenario: explicitly replace default and custom output files
# Given existing output files containing stale data
# When local-only symbolication runs with --force
# Then the output is replaced with the complete symbolicated report
test_force_output() {
    local output
    export PATH="$OFFLINE_PATH"
    for output in "$FIXTURE_DIR/report.symbolicated.json" "$FIXTURE_DIR/forced output.json"; do
        printf 'stale output\n' >"$output"
        if [[ "$output" = "$FIXTURE_DIR/report.symbolicated.json" ]]; then
            /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -l "$FIXTURE_DIR/app.dSYM" --local-only --force >"$FIXTURE_DIR/force.log" 2>&1
        else
            /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$output" -l "$FIXTURE_DIR/app.dSYM" --local-only --force >"$FIXTURE_DIR/force.log" 2>&1
        fi
        assert_symbolicated "$output"
    done
}

# Scenario: force never replaces the input or writes through symlinks
test_force_output_safety() {
    local output
    ln "$FIXTURE_DIR/report.json" "$FIXTURE_DIR/input-hardlink.json"
    ln -s "$FIXTURE_DIR/absent-target.json" "$FIXTURE_DIR/dangling-output.json"
    for output in "$FIXTURE_DIR/report.json" "$FIXTURE_DIR/output-link.json" "$FIXTURE_DIR/input-hardlink.json" "$FIXTURE_DIR/dangling-output.json" "$FIXTURE_DIR/empty"; do
        expect_failure force-unsafe remote -o "$output" --force --local-only
    done
    cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/report.json"
    [[ -L "$FIXTURE_DIR/output-link.json" && -L "$FIXTURE_DIR/dangling-output.json" ]]
    [[ ! -e "$FIXTURE_DIR/absent-target.json" ]]
    [[ -z "$(ls -A "$FIXTURE_DIR/empty")" ]]
}

# Scenario: a failed forced run leaves existing output intact
test_force_failure_preserves_output() {
    cp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/force-failure.json"
    expect_failure force-failure env LEGACY_MODE=failure /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/force-failure.json" -l "$FIXTURE_DIR/app.dSYM" --local-only --force
    grep -q 'Local symbol discovery failed' "$FIXTURE_DIR/force-failure.log"
    cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/force-failure.json"
}

# Scenario Outline: unavailable remote symbols leave frames unresolved
# Given missing symbols, a forbidden lookup, or a forbidden download
# When remote symbolication is attempted with verbose logging
# Then output preserves the report without exposing private error bodies
# And a forbidden download leaves no cached artifact
test_unavailable_remote_symbols() {
    local mode
    for mode in forbidden lookup-forbidden missing; do
        STUB_MODE="$mode" remote -o "$FIXTURE_DIR/$mode.json" -c "$FIXTURE_DIR/$mode-cache" -v >"$FIXTURE_DIR/$mode.log" 2>&1
        cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/$mode.json"
        assert_absent 'private error content' "$FIXTURE_DIR/$mode.log"
    done
    [[ -z "$(find "$FIXTURE_DIR/forbidden-cache" -type f)" ]]
    grep -q 'HTTP 403' "$FIXTURE_DIR/forbidden.log"
}

# Scenario: reject corrupt downloaded symbols
# Given a successful HTTP response containing invalid Mach-O data
# When its symbols are validated
# Then the command fails without producing a report or caching the download
test_corrupt_download() {
    expect_failure corrupt env STUB_MODE=corrupt /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -l "$FIXTURE_DIR/empty" -o "$FIXTURE_DIR/corrupt.json" -c "$FIXTURE_DIR/corrupt-cache"
    [[ ! -e "$FIXTURE_DIR/corrupt.json" && -z "$(find "$FIXTURE_DIR/corrupt-cache" -type f)" ]]
}

# Scenario: reject authentication failures and unsupported CLI versions
# Given an HTTP 401 lookup or an older sentry CLI
# When remote symbolication is requested
# Then the command fails rather than treating it as missing symbols
test_remote_prerequisite_failures() {
    expect_failure lookup env STUB_MODE=lookup-failure /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -l "$FIXTURE_DIR/empty" -o "$FIXTURE_DIR/lookup.json"
    grep -q 'HTTP 401' "$FIXTURE_DIR/lookup.log"
    expect_failure old-cli env STUB_VERSION=0.35.0 /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -l "$FIXTURE_DIR/empty" -o "$FIXTURE_DIR/old-cli.json"
    [[ ! -e "$FIXTURE_DIR/lookup.json" && ! -e "$FIXTURE_DIR/old-cli.json" ]]
}

# Scenario: continue after one image's download is forbidden
# Given one forbidden image and another downloadable matching image
# When both images are processed
# Then the accessible image is still symbolicated
test_forbidden_image_continuation() {
    STUB_MODE=forbidden-first remote -o "$FIXTURE_DIR/continue.json" -c "$FIXTURE_DIR/continue-cache" >"$FIXTURE_DIR/continue.log" 2>&1
    assert_symbolicated "$FIXTURE_DIR/continue.json"
}

# Scenario: use the documented default download cache
# Given no explicit cache directory
# When matching symbols are downloaded
# Then the validated artifact is saved below the current HOME
test_default_cache() {
    remote -o "$FIXTURE_DIR/default-cache.json" >"$FIXTURE_DIR/default-cache.log" 2>&1
    [[ -f "$HOME/Library/Caches/io.sentry.tools.metrickit-explorer/dsyms/$FIXTURE_UUID-$FIXTURE_ARCH-42.macho" ]]
    assert_symbolicated "$FIXTURE_DIR/default-cache.json"
}

# Scenario: support raw call-stack trees and explicit architecture selection
# Given equivalent wrapped and raw reports
# When the raw report is symbolicated with matching explicit CLI options
# Then its result equals the tree in the wrapped result
test_raw_report() {
    jq '.callStackTree' "$FIXTURE_DIR/report.json" >"$FIXTURE_DIR/raw.json"
    remote -o "$FIXTURE_DIR/raw-wrapped.json" -c "$FIXTURE_DIR/raw-cache" >"$FIXTURE_DIR/raw-wrapped.log" 2>&1
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/raw.json" -l "$FIXTURE_DIR/empty" -g fixture-org -p fixture-project -a "$FIXTURE_ARCH" -c "$FIXTURE_DIR/raw-cache" >"$FIXTURE_DIR/raw.log" 2>&1
    jq -e --slurpfile wrapped "$FIXTURE_DIR/raw-wrapped.json" '. == $wrapped[0].callStackTree' "$FIXTURE_DIR/raw.symbolicated.json" >/dev/null
}

# Scenario: use remote fallback only for locally unmatched images
# Given a local app dSYM and an unknown image
# When remote fallback is enabled
# Then only the unknown image triggers a Sentry lookup
test_local_first_remote_fallback() {
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/mixed.json" -l "$FIXTURE_DIR/app.dSYM" >"$FIXTURE_DIR/mixed.log" 2>&1
    assert_symbolicated "$FIXTURE_DIR/mixed.json"
    assert_absent "$FIXTURE_UUID" "$FIXTURE_DIR/calls"
    grep -q 'query=11111111-1111-1111-1111-111111111111' "$FIXTURE_DIR/calls"
}

# Scenario Outline: accept different local artifact inputs without remote tools
# Given a binary, app bundle, dSYM, or build directory with spaces in its path
# When local-only symbolication runs without the newer sentry executable
# Then the report is symbolicated quietly and a directory search prefers its dSYM
test_local_artifact_inputs() {
    local kind location
    export PATH="$OFFLINE_PATH"
    mkdir -p "$FIXTURE_DIR/Products/My App.app"
    cp "$FIXTURE_DIR/app" "$FIXTURE_DIR/Products/My App.app/app"
    cp -R "$FIXTURE_DIR/app.dSYM" "$FIXTURE_DIR/Products/My App.app.dSYM"
    for kind in file app dsym directory; do
        case "$kind" in
        file) location="$FIXTURE_DIR/Products/My App.app/app" ;;
        app) location="$FIXTURE_DIR/Products/My App.app" ;;
        dsym) location="$FIXTURE_DIR/Products/My App.app.dSYM" ;;
        directory) location="$FIXTURE_DIR/Products" ;;
        esac
        /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/local-$kind.json" -l "$location" -L >"$FIXTURE_DIR/local-$kind.log" 2>&1
        assert_symbolicated "$FIXTURE_DIR/local-$kind.json"
        assert_absent '\[debug\]' "$FIXTURE_DIR/local-$kind.log"
    done
    grep -q 'My App.app.dSYM/Contents/Resources/DWARF/app' "$FIXTURE_DIR/local-directory.log"
}

# Scenario: prefer a dSYM supplied after a binary
# Given repeated local-symbols options listing the binary before its dSYM
# When verbose local-only symbolication runs
# Then the dSYM is selected and timestamped progress appears only on stderr
test_repeated_local_paths() {
    export PATH="$OFFLINE_PATH"
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/repeated.json" -l "$FIXTURE_DIR/app" -l "$FIXTURE_DIR/app.dSYM" -L --verbose >"$FIXTURE_DIR/repeated.out" 2>"$FIXTURE_DIR/repeated.log"
    assert_symbolicated "$FIXTURE_DIR/repeated.json"
    grep -Eq '\[debug\] \[[0-9:]+\] \[\+[0-9]+s\]' "$FIXTURE_DIR/repeated.log"
    grep -q 'app.dSYM/Contents/Resources/DWARF/app' "$FIXTURE_DIR/repeated.log"
    assert_absent '\[debug\]' "$FIXTURE_DIR/repeated.out"
}

# Scenario: ignore symbols that do not match an architecture override
# Given an app dSYM and an incompatible architecture override
# When local-only symbolication runs
# Then the original report remains unresolved and unchanged
test_architecture_mismatch() {
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/wrong-arch.json" -l "$FIXTURE_DIR/app.dSYM" -L -a i386 >"$FIXTURE_DIR/wrong-arch.log" 2>&1
    cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/wrong-arch.json"
}

# Scenario Outline: reject invalid local inputs and finder failures
# Given a missing path, failed finder, or malformed finder JSON
# When local-only symbolication runs
# Then the command fails without producing an output report
test_local_discovery_failures() {
    local mode
    expect_failure missing-path /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/missing-path.json" -l "$FIXTURE_DIR/absent" -L
    [[ ! -e "$FIXTURE_DIR/missing-path.json" ]]
    for mode in failure invalid-json; do
        expect_failure "legacy-$mode" env LEGACY_MODE="$mode" /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/legacy-$mode.json" -l "$FIXTURE_DIR/app.dSYM" -L
        [[ ! -e "$FIXTURE_DIR/legacy-$mode.json" ]]
    done
}

# Scenario: defer remote CLI requirements when all images match locally
# Given every eligible image has local symbols and sentry is not on PATH
# When symbolication runs without the local-only flag
# Then it succeeds without initializing the remote CLI
test_fully_local_without_remote_cli() {
    export PATH="$OFFLINE_PATH"
    jq --arg uuid "$FIXTURE_UUID" '.callStackTree.callStacks[0].callStackRootFrames[0].subFrames |= map(select((.binaryUUID|ascii_downcase)==$uuid))' "$FIXTURE_DIR/report.json" >"$FIXTURE_DIR/all-local.json"
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/all-local.json" -l "$FIXTURE_DIR/app.dSYM" >"$FIXTURE_DIR/all-local.log" 2>&1
    [[ "$(count_resolved "$FIXTURE_DIR/all-local.symbolicated.json")" = 2 ]]
}

# Scenario: prioritize explicit paths over automatic device discovery
# Given matching device metadata, its cache, and explicit app/system dSYMs
# When local-only symbolication runs
# Then explicit symbols resolve both images before automatic discovery
# And the device architecture does not override the actual image architecture
test_explicit_device_precedence() {
    export PATH="$OFFLINE_PATH"
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/device-report.json" -o "$FIXTURE_DIR/device.json" -l "$FIXTURE_DIR/system/app.dSYM" -l "$FIXTURE_DIR/app.dSYM" -L -v >"$FIXTURE_DIR/device.log" 2>&1
    [[ "$(count_resolved "$FIXTURE_DIR/device.json")" = 4 ]] || fail 'Explicit symbols must resolve app and system images'
    grep 'Using local symbols' "$FIXTURE_DIR/device.log" | grep -Fq "$FIXTURE_DIR/system/app.dSYM/Contents/Resources/DWARF/app" || fail 'Explicit symbols must precede automatic device discovery'
    assert_absent 'Using local symbols.*SystemImage' "$FIXTURE_DIR/device.log"
    assert_preserved "$FIXTURE_DIR/device-report.json" "$FIXTURE_DIR/device.json"
}

# Scenario: discover device symbols without a supplied path
# Given report metadata identifying an existing device-symbol cache
# When local-only symbolication runs without local-symbols options
# Then matching system frames resolve and the unavailable app frames remain unresolved
test_automatic_device_symbols() {
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/device-report.json" -o "$FIXTURE_DIR/system-only.json" -L >"$FIXTURE_DIR/system-only.log" 2>&1
    [[ "$(count_resolved "$FIXTURE_DIR/system-only.json")" = 2 ]]
}

# Scenario Outline: fall back when the exact device cache cannot be inferred
# Given mismatched device/build/architecture, missing or malformed metadata, or an unsafe path component
# When local-only symbolication runs with an app dSYM fallback
# Then only the app image resolves and no device cache is selected
test_device_metadata_fallback() {
    local kind filter
    for kind in device build architecture missing malformed unsafe; do
        case "$kind" in
        device) filter='.diagnosticMetaData.deviceType = "iPad13,6"' ;;
        build) filter='.diagnosticMetaData.osVersion = "iPhone OS 27.0 (24A435)"' ;;
        architecture) filter='.diagnosticMetaData.platformArchitecture = "arm64"' ;;
        missing) filter='del(.diagnosticMetaData)' ;;
        malformed) filter='.diagnosticMetaData = {deviceType:42,osVersion:[],platformArchitecture:{}}' ;;
        unsafe) filter='.diagnosticMetaData.deviceType = "../../iPhone13,2"' ;;
        esac
        jq "$filter" "$FIXTURE_DIR/device-report.json" >"$FIXTURE_DIR/metadata-$kind-report.json"
        /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/metadata-$kind-report.json" -o "$FIXTURE_DIR/device-$kind.json" -l "$FIXTURE_DIR/app.dSYM" -L -v >"$FIXTURE_DIR/device-$kind.log" 2>&1
        [[ "$(count_resolved "$FIXTURE_DIR/device-$kind.json")" = 2 ]]
        assert_absent 'Found matching Xcode device symbols' "$FIXTURE_DIR/device-$kind.log"
    done
}

# Scenario: accept an explicit device-symbol path when metadata is absent
# Given no device metadata but explicit app and system symbol paths
# When local-only symbolication runs
# Then both app and system frames resolve
test_manual_device_fallback() {
    jq 'del(.diagnosticMetaData)' "$FIXTURE_DIR/device-report.json" >"$FIXTURE_DIR/manual-report.json"
    /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/manual-report.json" -o "$FIXTURE_DIR/manual-device.json" -l "$FIXTURE_DIR/app.dSYM" -l "$SYMBOLS" -L >"$FIXTURE_DIR/manual-device.log" 2>&1
    [[ "$(count_resolved "$FIXTURE_DIR/manual-device.json")" = 4 ]]
}

# Scenario: automatically resolve build products, preferring dSYMs to binaries
# Given matching artifacts in Derived Data, with spaces in their paths
# When local-only symbolication runs without explicit paths
# Then dSYMs supply source locations, with binaries used when no dSYM exists
test_automatic_derived_data() {
    local kind auto_home products
    export PATH="$OFFLINE_PATH"
    for kind in dsym binary; do
        auto_home="$FIXTURE_DIR/derived $kind home"
        products="$auto_home/Library/Developer/Xcode/DerivedData/My App-build/Build/Products/Debug-iphoneos"
        mkdir -p "$products/My App.app"
        cp "$FIXTURE_DIR/app" "$products/My App.app/app"
        if [[ "$kind" = dsym ]]; then
            cp -R "$FIXTURE_DIR/app.dSYM" "$products/My App.app.dSYM"
        fi
        HOME="$auto_home" /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/derived-$kind.json" -L -v >"$FIXTURE_DIR/derived-$kind.log" 2>&1
        [[ "$(count_resolved "$FIXTURE_DIR/derived-$kind.json")" = 2 ]] || fail "Derived Data $kind must resolve app frames"
        assert_preserved "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/derived-$kind.json"
        if [[ "$kind" = dsym ]]; then
            assert_symbolicated "$FIXTURE_DIR/derived-$kind.json"
            grep 'Using local symbols' "$FIXTURE_DIR/derived-$kind.log" | grep -Fq 'My App.app.dSYM/Contents/Resources/DWARF/app'
        fi
    done
}

# Scenario: explicit matches skip automatic discovery entirely
# Given all images match explicit symbols and Derived Data also contains matches
# When symbolication runs without the remote CLI
# Then only the explicit dSYM is searched and used
test_explicit_skips_automatic_discovery() {
    local auto_home="$FIXTURE_DIR/explicit home" products
    products="$auto_home/Library/Developer/Xcode/DerivedData/App-build/Build/Products"
    mkdir -p "$products"
    cp -R "$FIXTURE_DIR/app.dSYM" "$products/app.dSYM"
    jq --arg uuid "$FIXTURE_UUID" '.callStackTree.callStacks[0].callStackRootFrames[0].subFrames |= map(select((.binaryUUID|ascii_downcase)==$uuid))' "$FIXTURE_DIR/report.json" >"$FIXTURE_DIR/explicit-report.json"
    export PATH="$OFFLINE_PATH"
    HOME="$auto_home" /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/explicit-report.json" -o "$FIXTURE_DIR/explicit.json" -l "$FIXTURE_DIR/app.dSYM" -v >"$FIXTURE_DIR/explicit.log" 2>&1
    [[ "$(count_resolved "$FIXTURE_DIR/explicit.json")" = 2 ]]
    [[ "$(grep -c '^debug-files find ' "$FIXTURE_DIR/legacy-calls")" = 1 ]]
    assert_absent -E 'DerivedData|iOS DeviceSupport' "$FIXTURE_DIR/legacy-calls"
    assert_absent 'Scanning local path.*DerivedData' "$FIXTURE_DIR/explicit.log"
}

# Scenario: automatic searches are bounded and require UUID/architecture matches
# Given matching symbols outside Build/Products and a wrong-UUID binary inside it
# When discovery runs, or the architecture override mismatches an automatic dSYM
# Then frames remain unchanged
test_derived_data_scope_and_identity() {
    local auto_home="$FIXTURE_DIR/derived scope home" derived
    derived="$auto_home/Library/Developer/Xcode/DerivedData/App-build"
    mkdir -p "$derived/Index.noindex" "$derived/Build/Products"
    cp -R "$FIXTURE_DIR/app.dSYM" "$derived/Index.noindex/app.dSYM"
    cp "$FIXTURE_DIR/system/app" "$derived/Build/Products/app"
    HOME="$auto_home" /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/derived-scope.json" -L >"$FIXTURE_DIR/derived-scope.log" 2>&1
    cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/derived-scope.json"
    grep '^debug-files find ' "$FIXTURE_DIR/legacy-calls" | grep -Fq "$derived/Build/Products"
    assert_absent 'Index.noindex' "$FIXTURE_DIR/legacy-calls"
    cp -R "$FIXTURE_DIR/app.dSYM" "$derived/Build/Products/app.dSYM"
    HOME="$auto_home" /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/derived-arch.json" -L -a i386 >"$FIXTURE_DIR/derived-arch.log" 2>&1
    cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/derived-arch.json"
}

# Scenario: batch only unresolved images across multiple Derived Data projects
# Given explicit app symbols and automatic system symbols in two build directories
# When local-only symbolication runs
# Then both images resolve, and Derived Data lookup excludes the explicit UUID
test_derived_data_remaining_images() {
    local auto_home="$FIXTURE_DIR/derived remaining home" derived products
    derived="$auto_home/Library/Developer/Xcode/DerivedData"
    products="$derived/System-build/Build/Products/Debug-iphoneos"
    mkdir -p "$products" "$derived/Other-build/Build/Products"
    cp -R "$FIXTURE_DIR/system/app.dSYM" "$products/System.dSYM"
    HOME="$auto_home" /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/device-report.json" -o "$FIXTURE_DIR/derived-remaining.json" -l "$FIXTURE_DIR/app.dSYM" -L >"$FIXTURE_DIR/derived-remaining.log" 2>&1
    [[ "$(count_resolved "$FIXTURE_DIR/derived-remaining.json")" = 4 ]]
    assert_preserved "$FIXTURE_DIR/device-report.json" "$FIXTURE_DIR/derived-remaining.json"
    grep '^debug-files find .*DerivedData' "$FIXTURE_DIR/legacy-calls" >"$FIXTURE_DIR/derived-calls"
    assert_absent "$FIXTURE_UUID" "$FIXTURE_DIR/derived-calls"
    [[ "$(wc -l <"$FIXTURE_DIR/derived-calls" | tr -d ' ')" = 2 ]]
    grep -Fq -- "--path $derived/Other-build/Build/Products --path $derived/System-build/Build/Products" "$FIXTURE_DIR/derived-calls"
}

# Scenario: do not search the machine when no local paths are available
# Given no device metadata and no explicit fallback paths
# When local-only symbolication runs with a finder that would fail if invoked
# Then no finder runs and the output equals the original report
test_no_unbounded_discovery() {
    env LEGACY_MODE=failure /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/report.json" -o "$FIXTURE_DIR/no-paths.json" -L >"$FIXTURE_DIR/no-paths.log" 2>&1
    cmp "$FIXTURE_DIR/report.json" "$FIXTURE_DIR/no-paths.json"
}

# Scenario: reject an image whose UUID does not match the report
# Given an exactly named device cache containing a different binary
# When local-only symbolication runs with an app dSYM fallback
# Then the unmatched system image stays unresolved
test_device_uuid_validation() {
    local wrong_home="$FIXTURE_DIR/wrong uuid home" wrong_symbols
    wrong_symbols="$wrong_home/Library/Developer/Xcode/iOS DeviceSupport/iPhone13,2 27.0 (24A437)/arm64e/Symbols"
    mkdir -p "$wrong_symbols"
    cp "$FIXTURE_DIR/app.dSYM/Contents/Resources/DWARF/app" "$wrong_symbols/SystemImage"
    HOME="$wrong_home" /bin/bash "$SCRIPT" -r "$FIXTURE_DIR/device-report.json" -o "$FIXTURE_DIR/wrong-uuid.json" -l "$FIXTURE_DIR/app.dSYM" -L >"$FIXTURE_DIR/wrong-uuid.log" 2>&1
    [[ "$(count_resolved "$FIXTURE_DIR/wrong-uuid.json")" = 2 ]]
}

run_case test_remote_resolution
run_case test_cache_reuse
run_case test_verbose_progress
run_case test_output_and_argument_validation
run_case test_force_output
run_case test_force_output_safety
run_case test_force_failure_preserves_output
run_case test_unavailable_remote_symbols
run_case test_corrupt_download
run_case test_remote_prerequisite_failures
run_case test_forbidden_image_continuation
run_case test_default_cache
run_case test_raw_report
run_case test_local_first_remote_fallback
run_case test_local_artifact_inputs
run_case test_repeated_local_paths
run_case test_architecture_mismatch
run_case test_local_discovery_failures
run_case test_fully_local_without_remote_cli
run_case test_automatic_derived_data
run_case test_explicit_skips_automatic_discovery
run_case test_derived_data_scope_and_identity
run_case test_derived_data_remaining_images
run_case test_explicit_device_precedence
run_case test_automatic_device_symbols
run_case test_device_metadata_fallback
run_case test_manual_device_fallback
run_case test_no_unbounded_discovery
run_case test_device_uuid_validation
cmp "$FIXTURE_DIR/original.json" "$FIXTURE_DIR/report.json"
echo "PASS: $TEST_COUNT symbolication scenarios"
