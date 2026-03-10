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

## Commands

| Command                    | Description                               |
| -------------------------- | ----------------------------------------- |
| `make build-samples`       | Build all sample apps                     |
| `make build-sample-<name>` | Build specific sample (e.g., `iOS-Swift`) |
| `make xcode-ci`            | Regenerate all Xcode projects             |
| `make xcode-ci-<name>`     | Regenerate specific project (e.g., `SPM`) |
