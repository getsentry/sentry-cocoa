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
# Regenerate and build a specific sample
make build-sample-iOS-Swift

# Regenerate all Xcode projects
make xcode-ci
```

Rationale: The Makefile ensures correct build order and dependencies (e.g., SentrySampleShared must be generated before iOS-Swift).

## Commands

| Command                    | Description                               |
| -------------------------- | ----------------------------------------- |
| `make build-samples`       | Build all sample apps                     |
| `make build-sample-<name>` | Build specific sample (e.g., `iOS-Swift`) |
| `make xcode-ci`            | Regenerate all Xcode projects             |
| `make xcode-ci-<name>`     | Regenerate specific project (e.g., `SPM`) |
