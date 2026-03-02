# Samples — Agent Instructions

## Project Structure

Each sample app follows a consistent directory layout:

```
TargetName/
├── Sources/         # Swift/ObjC source files
├── Resources/       # Assets, storyboards, etc.
└── Configuration/   # Info.plist, entitlements, xcconfig files
```

Example: `App/Sources`, `App/Resources`, `App/Configuration`

- **Info.plist and entitlements** live in `Configuration/`, not `Resources/`
- **Empty directories**: Add `.gitkeep` to empty Sources, Resources, Configuration dirs so git tracks the layout

## Build & Regenerate

```bash
# Build all sample apps
make build-samples

# Build a specific sample
make build-sample-<name>    # e.g., make build-sample-iOS-Swift

# Regenerate all sample Xcode projects (via XcodeGen)
make xcode-ci

# Regenerate a specific sample project
make xcode-ci-<name>        # e.g., make xcode-ci-SPM
```
