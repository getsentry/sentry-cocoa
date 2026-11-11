# Test Apps

> Scope: `TestApps/**`. Also follow [root instructions](../AGENTS.md).

## Layout

- Put source in `Sources/`, assets in `Resources/`, and Info.plist, entitlements, and xcconfig files in `Configuration/`
- Preserve empty required directories with `.gitkeep`

## Project Generation and Commands

- Generate XcodeGen-based test app projects through Make targets, never by invoking `xcodegen` directly
- Make project configuration changes in the app's `.yml` specification, then regenerate its project
- Use `FOR_AGENTS=true` for supported SDK platform build/test targets. Inspect `raw-*-output.log` only when reduced output is inconclusive

| Command                                      | Purpose                          |
| -------------------------------------------- | -------------------------------- |
| `swift build --package-path TestApps/<name>` | Build one package-based test app |
| `make xcode-ci-<name>`                       | Generate one XcodeGen project    |
| `make xcode-ci`                              | Generate all XcodeGen projects   |
| `make build-testapp-<name>`                  | Generate and build one test app  |
| `make build-testapps`                        | Generate and build all test apps |
| `make test-testapp-<name>-ui`                | Run one test app's UI tests      |
| `make test-testapps-ui`                      | Run all test app UI tests        |
| `make test-ui-critical`                      | Run critical UI coverage         |

## Validation

- Build affected test apps with `make build-testapp-<name>`
- Run affected UI tests with `make test-testapp-<name>-ui` when behavior changes
- Use `make test-ui-critical` for critical UI coverage
- Follow assertion conventions in [`Tests/AGENTS.md`](../Tests/AGENTS.md)

## Test Apps with UI Tests

The following test apps have UI test suites:

- `iOS-Swift` — Comprehensive UI tests for iOS Swift test app
- `iOS-SwiftUI` — SwiftUI-specific UI tests including feedback
- `iOS-Swift6` — Swift 6 compatibility tests
- `iOS-ObjectiveC` — Objective-C UI tests
- `macOS-Swift` — macOS app UI tests
- `tvOS-Swift` — tvOS app UI tests

Each UI test target follows the naming pattern `<TestAppName>-UITests` and references a test plan at `Plans/<TestAppName>_Base.xctestplan`.
