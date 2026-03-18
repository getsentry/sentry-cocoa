# SentryObjC XCFramework Design

## Overview

Build a standalone `SentryObjC.xcframework` that provides pure Objective-C headers for consumers who cannot use Clang modules (e.g., ObjC++ projects with `-fmodules=NO`).

## Requirements

- Single `SentryObjC.xcframework` with everything embedded (ObjC wrapper + Swift bridge + full SDK)
- All platforms: iOS, macOS (+ Catalyst), tvOS, watchOS, visionOS
- Part of regular release process alongside `Sentry.xcframework`
- Full API parity with main SDK
- Pure ObjC public headers using same type names (`SentryOptions`, `SentrySDK`, etc.)

## Architecture

### Three-Tier Structure

```
┌─────────────────────────────────────────────────────────┐
│ Public: SentryObjC Headers (Pure ObjC)                  │
│   SentrySDK, SentryOptions, SentryUser, etc.            │
└─────────────────────────────────────────────────────────┘
                          │ calls
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Internal: SentryObjCBridge (Swift)                      │
│   Converts wrapper types ↔ real SDK types               │
└─────────────────────────────────────────────────────────┘
                          │ calls
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Internal: Full Sentry SDK (compiled in)                 │
└─────────────────────────────────────────────────────────┘
```

### Type Architecture

Each public type is a complete `@interface` definition (not a forward declaration) that:

- Holds an internal reference to the real SDK type
- Exposes the same properties/methods as pure ObjC
- Bridges through `SentryObjCBridge` for conversions

Type names match the main SDK: `SentryOptions`, `SentryUser`, `SentryBreadcrumb`, etc.

## XCFramework Structure

```
SentryObjC.xcframework/
├── Info.plist
├── _CodeSignature/
├── ios-arm64/
│   ├── SentryObjC.framework/
│   │   ├── SentryObjC (binary)
│   │   ├── Info.plist
│   │   ├── PrivacyInfo.xcprivacy
│   │   ├── Headers/
│   │   │   ├── SentryObjC.h (umbrella)
│   │   │   ├── SentrySDK.h
│   │   │   ├── SentryOptions.h
│   │   │   └── ... (pure ObjC headers)
│   │   ├── PrivateHeaders/
│   │   └── Modules/
│   │       └── module.modulemap
│   └── dSYMs/
├── ios-arm64_x86_64-simulator/
├── ios-arm64_x86_64-maccatalyst/
├── macos-arm64_x86_64/
├── tvos-arm64/
├── tvos-arm64_x86_64-simulator/
├── watchos-arm64_arm64_32_armv7k/
├── watchos-arm64_x86_64-simulator/
├── xros-arm64/
└── xros-arm64_x86_64-simulator/
```

### Module Map

```
framework module SentryObjC {
    umbrella header "SentryObjC.h"
    export *
    module * { export * }
}
```

No Swift module - pure ObjC only.

## Header Reorganization

### Naming Convention

- Files: `Sentry<Type>.h` (e.g., `SentryOptions.h`)
- Classes: `Sentry<Type>` (e.g., `SentryOptions`)
- Umbrella: `SentryObjC.h`

### File Renames

| Current                  | Target               |
| ------------------------ | -------------------- |
| `SentryObjCSDK.h`        | `SentrySDK.h`        |
| `SentryObjCUser.h`       | `SentryUser.h`       |
| `SentryObjCOptions.h`    | `SentryOptions.h`    |
| `SentryObjCBreadcrumb.h` | `SentryBreadcrumb.h` |
| ...                      | ...                  |

### Forward Declarations → Full Definitions

Types currently forward-declared (e.g., `@class SentryOptions;`) must become full `@interface` definitions with all properties and methods.

## Build Process

### Xcode Project

- Add `SentryObjC` framework target to `Sentry.xcodeproj`
- Compiles: `Sources/SentryObjC/*.m` + `Sources/SentryObjCBridge/*.swift`
- Links: Sentry target (full SDK compiled in)
- Public headers: `Sources/SentryObjC/Public/*.h`

### Scripts

Reuse existing infrastructure:

```
scripts/build-xcframework-local.sh
    └── build-xcframework-variant.sh (add SentryObjC variant)
        └── build-xcframework-slice.sh
            └── xcodebuild archive -scheme SentryObjC
```

### Makefile Targets

```makefile
build-sentryobjc              # Build for iOS simulator (dev/test)
build-sentryobjc-xcframework  # Build full xcframework (all platforms)
```

### CI Integration

- Add to release workflow alongside other xcframework variants
- Output: `SentryObjC.xcframework.zip` in GitHub releases

## Consumer Usage

```objc
// In .mm file with CLANG_ENABLE_MODULES=NO
#import <SentryObjC/SentryObjC.h>

[SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
    options.dsn = @"...";
    options.tracesSampleRate = @1.0;
    options.sessionReplay.sessionSampleRate = 0;
}];
```

## Out of Scope

- SentrySwiftUI support (requires Swift/SwiftUI)
- Hybrid SDK bridges (React Native, Flutter use their own wrappers)
