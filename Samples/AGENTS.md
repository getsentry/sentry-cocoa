# Samples

## Directory Layout

```
TargetName/
├── Sources/         # Swift/ObjC source files
├── Resources/       # Assets, storyboards
└── Configuration/   # Info.plist, entitlements, xcconfig
```

- Info.plist and entitlements go in `Configuration/`, not `Resources/`
- Add `.gitkeep` to empty directories

## Commands

| Command                    | Description                               |
| -------------------------- | ----------------------------------------- |
| `make build-samples`       | Build all sample apps                     |
| `make build-sample-<name>` | Build specific sample (e.g., `iOS-Swift`) |
| `make xcode-ci`            | Regenerate all Xcode projects             |
| `make xcode-ci-<name>`     | Regenerate specific project (e.g., `SPM`) |
