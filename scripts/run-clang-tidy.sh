#!/usr/bin/env bash

# Runs clang-tidy with google-objc-avoid-nsobject-new check on Objective-C files.
# Requires compile_commands.json (generated via make generate-compile-commands).
#
# Usage:
#   ./scripts/run-clang-tidy.sh           # Check only
#   ./scripts/run-clang-tidy.sh --fix     # Check and apply fixes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILE_DB="$REPO_ROOT/compile_commands.json"

cd "$REPO_ROOT"

if [[ ! -f "$COMPILE_DB" ]]; then
    echo "Error: compile_commands.json not found."
    echo "Run 'make generate-compile-commands' first to generate it."
    exit 1
fi

# Use Homebrew's clang-tidy if available (from llvm formula)
CLANG_TIDY=""
if brew --prefix llvm &>/dev/null && [[ -x "$(brew --prefix llvm)/bin/clang-tidy" ]]; then
    CLANG_TIDY="$(brew --prefix llvm)/bin/clang-tidy"
elif command -v clang-tidy &>/dev/null; then
    CLANG_TIDY="clang-tidy"
else
    echo "Error: clang-tidy not found. Run 'make init-ci-format' or 'brew install llvm'."
    exit 1
fi

# Extract .m and .mm files from compile_commands.json
# File paths may be relative to "directory" - resolve them
FILES=()
while IFS= read -r line; do
    dir="${line%%|*}"
    file="${line##*|}"
    if [[ -z "$dir" || -z "$file" ]]; then
        continue
    fi
    # Resolve path: if file is absolute, use as-is; else join with directory
    if [[ "$file" == /* ]]; then
        resolved="$file"
    else
        resolved="$dir/$file"
    fi
    if [[ "$file" == *.m || "$file" == *.mm ]]; then
        if [[ "$resolved" != *"/Pods/"* && "$resolved" != *"/Build/"* && "$resolved" != *"/.build/"* ]]; then
            if [[ -f "$resolved" ]]; then
                FILES+=("$resolved")
            fi
        fi
    fi
done < <(jq -r '.[] | "\(.directory)|\(.file)"' "$COMPILE_DB" 2>/dev/null | sort -u)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "No Objective-C files found in compile_commands.json."
    exit 0
fi

FIX_ARG=""
if [[ "${1:-}" == "--fix" ]]; then
    FIX_ARG="--fix"
fi

FAILED=0
for file in "${FILES[@]}"; do
    if ! "$CLANG_TIDY" -p "$REPO_ROOT" $FIX_ARG "$file" -- -fno-caret-diagnostics -fno-color-diagnostics; then
        FAILED=1
    fi
done

exit $FAILED
