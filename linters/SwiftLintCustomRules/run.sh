#!/bin/bash
set -euo pipefail

# Lint the Cocoa SDK with the Bazel-built SwiftLint extra-rules binary.
# Tests live under Tests/ and run via `bazel test //:StandaloneObjCExtensionRuleTests`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$SCRIPT_DIR/.swiftlint.yml"

if ! command -v bazel >/dev/null 2>&1; then
    echo "error: bazel (bazelisk) is required. Run 'brew install bazelisk' or 'make init'." >&2
    exit 1
fi

paths=()
if [[ $# -eq 0 ]]; then
    paths+=("$REPO_ROOT/Sources")
else
    for p in "$@"; do
        if [[ "$p" == /* ]]; then
            paths+=("$p")
        else
            paths+=("$REPO_ROOT/$p")
        fi
    done
fi

pushd "$SCRIPT_DIR"
bazel build @SwiftLint//:swiftlint
bazel @SwiftLint//:swiftlint -- \
    --config "$CONFIG" \
    --strict \
    --quiet \
    "${paths[@]}"
popd
