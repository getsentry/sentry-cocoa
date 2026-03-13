# Samples

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

## Directory Layout

```
TargetName/
├── Sources/         # Swift/ObjC source files
├── Resources/       # Assets, storyboards
└── Configuration/   # Info.plist, entitlements, xcconfig
```

- Info.plist and entitlements go in `Configuration/`, not `Resources/`
- Add `.gitkeep` to empty directories

## UI Tests

Follow assertion conventions in [`Tests/AGENTS.md`](../Tests/AGENTS.md) — see "Prefer Specific Assertions Over `XCTAssert`".

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

Rationale: The Makefile ensures correct build order and dependencies (e.g., SentrySampleShared must be generated before iOS-Swift).

## Sample Workflow

For each sample app, you can:

1. **Generate** — Create/update Xcode project from `.yml` spec
2. **Build** — Compile the sample app
3. **Test** — Run UI tests (for samples with UI test suites)

## Commands

| Command                         | Description                                            |
| ------------------------------- | ------------------------------------------------------ |
| **Generate (Project Creation)** |                                                        |
| `make xcode-ci`                 | Regenerate all Xcode projects                          |
| `make xcode-ci-<name>`          | Regenerate specific project (e.g., `xcode-ci-SPM`)     |
| **Build**                       |                                                        |
| `make build-samples`            | Build all sample apps                                  |
| `make build-sample-<name>`      | Build specific sample (e.g., `build-sample-iOS-Swift`) |
| **Test (UI Tests)**             |                                                        |
| `make test-samples-ui`          | Run all sample UI tests                                |
| `make test-sample-<name>-ui`    | Run specific sample UI tests (e.g., `iOS-Swift-ui`)    |
| `make test-ui-critical`         | Run critical UI test suites for validation             |

## Samples with UI Tests

The following samples have UI test suites:

- `iOS-Swift` — Comprehensive UI tests for iOS Swift sample
- `iOS-SwiftUI` — SwiftUI-specific UI tests including feedback
- `iOS-Swift6` — Swift 6 compatibility tests
- `iOS-ObjectiveC` — Objective-C UI tests
- `macOS-Swift` — macOS app UI tests
- `tvOS-Swift` — tvOS app UI tests

Each UI test target follows the naming pattern `<SampleName>-UITests` and references a test plan at `Plans/<SampleName>_Base.xctestplan`.
