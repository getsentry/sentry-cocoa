# SwiftLint custom rules

Native SwiftLint extra rules compiled into SwiftLint via Bazel.

```text
Sources/   Rule implementations (globbed into extra_rules)
Tests/     Swift Testing (bazel test //:StandaloneObjCExtensionRuleTests)
run.sh     Lints the Cocoa SDK Sources/ with the extra-rules binary
```

Homebrew SwiftLint cannot load extra rules. `make check-objc-standalone-extensions`
builds `@SwiftLint//:swiftlint` and runs only `standalone_objc_extension` against
the SDK (default: repo `Sources/`).

## Commands

From the repository root:

```sh
# Lint the Cocoa SDK (make lint / CI)
make check-objc-standalone-extensions

# Swift Testing for extra rules
make test-swiftlint-custom-rules
```

Requires [bazelisk](https://github.com/bazelbuild/bazelisk) (`brew install bazelisk`
or `make init-ci-format`). The first build compiles SwiftLint and takes several
minutes; later runs are cached.

Suppress a file with `// swiftlint:disable standalone_objc_extension`.

## Adding a rule

1. Add a `@SwiftSyntaxRule` type under `Sources/`.
2. Register it in `Sources/ExtraRules.swift`.
3. Add tests under `Tests/`.
4. Keep the SwiftLint module version in `MODULE.bazel` in sync with
   `scripts/.swiftlint-version`. `make update-versions` / `make init` patches
   both; `make check-versions` fails if they drift.
