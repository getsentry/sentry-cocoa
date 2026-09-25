#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/.swiftlint.yml"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v bazel >/dev/null 2>&1; then
    echo "error: bazel (bazelisk) is required. Run 'brew install bazelisk' or 'make init-ci-format'." >&2
    exit 1
fi

cd "$SCRIPT_DIR"
bazel build @SwiftLint//:swiftlint
SWIFTLINT="$SCRIPT_DIR/bazel-bin/external/swiftlint+/swiftlint"

failures=0

run_lint() {
    local file="$1"
    "$SWIFTLINT" --config "$CONFIG" --strict --quiet "$file"
}

expect_violation() {
    local name="$1"
    local file="$TMP/${name}.swift"
    cat >"$file"
    local output
    output="$(run_lint "$file" 2>&1)" && {
        echo "FAIL $name: expected a standalone_objc_extension violation" >&2
        failures=$((failures + 1))
        return
    }
    if ! grep -q "standalone_objc_extension" <<<"$output"; then
        echo "FAIL $name: missing standalone_objc_extension in output" >&2
        echo "$output" >&2
        failures=$((failures + 1))
        return
    fi
    if ! grep -q "Triggering code:" <<<"$output"; then
        echo "FAIL $name: missing triggering code in output" >&2
        echo "$output" >&2
        failures=$((failures + 1))
        return
    fi
    echo "OK   $name (violation)"
}

expect_clean() {
    local name="$1"
    local file="$TMP/${name}.swift"
    cat >"$file"
    if run_lint "$file" >/dev/null 2>&1; then
        echo "OK   $name (clean)"
    else
        echo "FAIL $name: expected no violations" >&2
        run_lint "$file" >&2 || true
        failures=$((failures + 1))
    fi
}

expect_violation objc-extension <<'EOF'
@objc extension Foo {}
EOF

expect_violation single-line-member <<'EOF'
extension Foo { @objc func bar() {} }
EOF

expect_violation multiline-member <<'EOF'
extension Foo {
    @objc func bar() {}
}
EOF

expect_violation objc-on-same-line-as-brace <<'EOF'
extension Foo { @objc
    func bar() {}
}
EOF

expect_violation multiline-attributes <<'EOF'
@objc
@available(iOS 13, *)
extension Foo {}
EOF

expect_violation same-file-objc-protocol <<'EOF'
@objc protocol P {}
extension Foo: P {}
EOF

expect_violation protocol-composition <<'EOF'
protocol P {}
@objc protocol Q {}
extension Foo: P & Q {}
EOF

expect_violation retroactive-conformance <<'EOF'
@objc protocol P {}
extension Foo: @retroactive P {}
EOF

expect_violation objc-init <<'EOF'
extension Options {
    @objc(initWithDictionary:didFailWithError:)
    public convenience init?(dictionary: [String: Any], didFailWithError error: NSErrorPointer) {}
}
EOF

expect_clean dummy-class <<'EOF'
@objc class Dummy: NSObject {}
@objc extension Foo {}
EOF

expect_clean nonisolated-class <<'EOF'
nonisolated(unsafe) class Dummy: NSObject {}
@objc extension Foo {}
EOF

expect_clean struct-counts <<'EOF'
struct Dummy {}
@objc extension Foo {}
EOF

expect_clean protocol-extension <<'EOF'
@objc protocol P { func x() }
extension P { func x() {} }
EOF

expect_clean swift-only-extension <<'EOF'
extension Foo { func bar() {} }
EOF

expect_clean nested-objc-class <<'EOF'
extension Foo { @objc class Nested: NSObject {} }
EOF

expect_clean swiftlint-disable <<'EOF'
// swiftlint:disable standalone_objc_extension
@objc extension Foo {}
EOF

if [[ "$failures" -ne 0 ]]; then
    echo "Failed $failures fixture(s)" >&2
    exit 1
fi

echo "All standalone_objc_extension fixtures passed."
