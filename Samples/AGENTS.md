# Samples

> Scope: `Samples/**`. Also follow [root instructions](../AGENTS.md).

## Layout

- Put source in `Sources/`, assets in `Resources/`, and Info.plist, entitlements, and xcconfig files in `Configuration/`
- Preserve empty required directories with `.gitkeep`

## Project Generation

- Generate XcodeGen-based sample projects through Make targets, never by invoking `xcodegen` directly
- Build one package-based sample with `swift build --package-path Samples/<name>`
- Generate one XcodeGen project with `make xcode-ci-<name>`
- Generate all XcodeGen projects with `make xcode-ci`
- Generate and build one sample with `make build-sample-<name>`

## Validation

- Build affected samples with `make build-sample-<name>`
- Run affected UI tests with `make test-sample-<name>-ui` when behavior changes
- Use `make test-ui-critical` for critical UI coverage
- Follow assertion conventions in [`Tests/AGENTS.md`](../Tests/AGENTS.md)

## Generating Sample Projects

**CRITICAL**: ALWAYS use the Makefile to regenerate sample projects. Never run `xcodegen` directly.

```bash
# Regenerate a specific project (without building)
make xcode-ci-iOS-Swift

# Regenerate all Xcode projects
make xcode-ci

# Regenerate AND build a specific sample
make build-sample-iOS-Swift
```

## Sample Workflow

For each sample app, you can:

1. **Generate** — Create/update Xcode project from `.yml` spec
2. **Build** — Compile the sample app
3. **Test** — Run UI tests (for samples with UI test suites)

## Commands

| Command                         | Description                                                                                                                       |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Generate (Project Creation)** |                                                                                                                                   |
| `make xcode-ci`                 | Regenerate all Xcode projects                                                                                                     |
| `make xcode-ci-<name>`          | Regenerate specific project (e.g., `xcode-ci-SPM`)                                                                                |
| **Build**                       |                                                                                                                                   |
| `make build-samples`            | Build all sample apps                                                                                                             |
| `make build-sample-<name>`      | Build specific sample (e.g., `build-sample-iOS-Swift`)                                                                            |
| `make <target> FOR_AGENTS=true` | Reduce output for supported SDK platform build/test targets. Inspect `raw-*-output.log` only when reduced output is inconclusive. |
| **Test (UI Tests)**             |                                                                                                                                   |
| `make test-samples-ui`          | Run all sample UI tests                                                                                                           |
| `make test-sample-<name>-ui`    | Run specific sample UI tests (e.g., `iOS-Swift-ui`)                                                                               |
| `make test-ui-critical`         | Run critical UI test suites for validation                                                                                        |

## Samples with UI Tests

The following samples have UI test suites:

- `iOS-Swift` — Comprehensive UI tests for iOS Swift sample
- `iOS-SwiftUI` — SwiftUI-specific UI tests including feedback
- `iOS-Swift6` — Swift 6 compatibility tests
- `iOS-ObjectiveC` — Objective-C UI tests
- `macOS-Swift` — macOS app UI tests
- `tvOS-Swift` — tvOS app UI tests

Each UI test target follows the naming pattern `<SampleName>-UITests` and references a test plan at `Plans/<SampleName>_Base.xctestplan`.
