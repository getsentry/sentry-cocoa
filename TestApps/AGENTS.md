# Test Apps

> Scope: `TestApps/**`. Also follow [root instructions](../AGENTS.md).

## Layout

- Put source in `Sources/`, assets in `Resources/`, and Info.plist, entitlements, and xcconfig files in `Configuration/`
- Preserve empty required directories with `.gitkeep`

## Project Generation

- Generate XcodeGen-based test app projects through Make targets, never by invoking `xcodegen` directly
- Build one package-based test app with `swift build --package-path TestApps/<name>`
- Generate one XcodeGen project with `make xcode-ci-<name>`
- Generate all XcodeGen projects with `make xcode-ci`
- Generate and build one testapp with `make build-testapp-<name>`

## Validation

- Build affected test apps with `make build-testapp-<name>`
- Run affected UI tests with `make test-testapp-<name>-ui` when behavior changes
- Use `make test-ui-critical` for critical UI coverage
- Follow assertion conventions in [`Tests/AGENTS.md`](../Tests/AGENTS.md)

## Generating TestApp Projects

**CRITICAL**: ALWAYS use the Makefile to regenerate test app projects. Never run `xcodegen` directly.

```bash
# Regenerate a specific project (without building)
make xcode-ci-iOS-Swift

# Regenerate all Xcode projects
make xcode-ci

# Regenerate AND build a specific test app
make build-testapp-iOS-Swift
```

## TestApp Workflow

For each test app, you can:

1. **Generate** — Create/update Xcode project from `.yml` spec
2. **Build** — Compile the test app
3. **Test** — Run UI tests (for apps with UI test suites)

## Commands

| Command                         | Description                                                                                                                       |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Generate (Project Creation)** |                                                                                                                                   |
| `make xcode-ci`                 | Regenerate all Xcode projects                                                                                                     |
| `make xcode-ci-<name>`          | Regenerate specific project (e.g., `xcode-ci-SPM`)                                                                                |
| **Build**                       |                                                                                                                                   |
| `make build-testapps`           | Build all test apps                                                                                                               |
| `make build-testapp-<name>`     | Build specific test app (e.g., `build-testapp-iOS-Swift`)                                                                         |
| `make <target> FOR_AGENTS=true` | Reduce output for supported SDK platform build/test targets. Inspect `raw-*-output.log` only when reduced output is inconclusive. |
| **Test (UI Tests)**             |                                                                                                                                   |
| `make test-testapps-ui`         | Run all test app UI tests                                                                                                         |
| `make test-testapp-<name>-ui`   | Run specific test app UI tests (e.g., `iOS-Swift-ui`)                                                                             |
| `make test-ui-critical`         | Run critical UI test suites for validation                                                                                        |

## Test Apps with UI Tests

The following test apps have UI test suites:

- `iOS-Swift` — Comprehensive UI tests for iOS Swift test app
- `iOS-SwiftUI` — SwiftUI-specific UI tests including feedback
- `iOS-Swift6` — Swift 6 compatibility tests
- `iOS-ObjectiveC` — Objective-C UI tests
- `macOS-Swift` — macOS app UI tests
- `tvOS-Swift` — tvOS app UI tests

Each UI test target follows the naming pattern `<TestAppName>-UITests` and references a test plan at `Plans/<TestAppName>_Base.xctestplan`.
