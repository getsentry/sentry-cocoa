# SwiftLint custom rules

Native SwiftLint extra rules compiled into SwiftLint via Bazel. The workspace
lives here so Bazel files stay out of the repository root.

Homebrew SwiftLint cannot load these rules. `make check-objc-standalone-extensions`
builds `@SwiftLint//:swiftlint` with the extra rules and runs only
`standalone_objc_extension`.

## Commands

From the repository root:

```sh
# Lint Sources (also invoked by make lint / CI)
make check-objc-standalone-extensions

# Fixture tests for standalone_objc_extension
make test-swiftlint-custom-rules
```

Requires [bazelisk](https://github.com/bazelbuild/bazelisk) (`brew install bazelisk`
or `make init-ci-format`). The first build compiles SwiftLint and takes several
minutes; later runs are cached.

Suppress a file with `// swiftlint:disable standalone_objc_extension`.

## Adding a rule

1. Add a `@SwiftSyntaxRule` type next to `StandaloneObjCExtensionRule.swift`.
2. Register it in `ExtraRules.swift`.
3. Add the file to the `extra_rules` filegroup in `BUILD.bazel`.
4. Keep the SwiftLint module version in `MODULE.bazel` in sync with
   `scripts/.swiftlint-version`.
