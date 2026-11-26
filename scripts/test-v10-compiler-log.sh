#!/bin/bash
set -euo pipefail

# Check response-file expansion without confusing macOS loader paths with files.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
READER="$WORK_DIR/reader"
swiftc "$SCRIPT_DIR/read-v10-compiler-evidence.swift" -o "$READER"
COMPILER="$(xcrun --find clang)"

check() {
    "$READER" --build-log "$WORK_DIR/build.log" > "$WORK_DIR/records.json"
    jq -e --arg response "@$WORK_DIR/compile.rsp" '
      length == 1 and .[0].source == "/fixture/source.c" and
      .[0].output == "/fixture/source.o" and
      (.[0].arguments | index("-c") != null and index($response) == null)
    ' "$WORK_DIR/records.json" > /dev/null
}

printf '%s\n' '-c /fixture/source.c -o /fixture/source.o' > "$WORK_DIR/compile.rsp"
for placeholder in '@loader_path' '@executable_path' '@rpath'; do
    for suffix in '' '/Frameworks'; do
        printf '%s @%s -Xlinker -rpath -Xlinker %s\n' \
            "$COMPILER" "$WORK_DIR/compile.rsp" "$placeholder$suffix" > "$WORK_DIR/build.log"
        check
        jq -e --arg path "$placeholder$suffix" '.[0].arguments | index($path) != null' \
            "$WORK_DIR/records.json" > /dev/null
        log_info "PASS loader path: $placeholder$suffix"
    done
done

# Loader-looking filenames without the exact placeholder boundary are still response files.
for response in "$WORK_DIR/missing.rsp" 'loader_pathology'; do
    printf '%s @%s\n' "$COMPILER" "$response" > "$WORK_DIR/build.log"
    if "$READER" --build-log "$WORK_DIR/build.log" > "$WORK_DIR/records.json" 2> "$WORK_DIR/error.log"; then
        log_error "Missing response file unexpectedly accepted: $response"
        exit 1
    fi
    grep -Fq 'Missing/cyclic response file' "$WORK_DIR/error.log"
done

printf '@%s\n' "$WORK_DIR/cycle.rsp" > "$WORK_DIR/cycle.rsp"
printf '%s @%s\n' "$COMPILER" "$WORK_DIR/cycle.rsp" > "$WORK_DIR/build.log"

if "$READER" --build-log "$WORK_DIR/build.log" > "$WORK_DIR/records.json" 2> "$WORK_DIR/error.log"; then
    log_error 'Cyclic response file unexpectedly accepted'
    exit 1
fi

grep -Fq 'Missing/cyclic response file' "$WORK_DIR/error.log"
log_info 'Response-file and loader-path checks passed'
