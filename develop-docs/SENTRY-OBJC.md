# SentryObjC Architecture

SentryObjC is a pure Objective-C wrapper around the Sentry SDK, designed for consumers who cannot use Clang modules (e.g., ObjC++ projects with `-fmodules=NO`).

## Problem

Many projects cannot enable Clang modules:

- **React Native** (≤0.76): AppDelegate is `.mm` (Objective-C++), modules disabled by default
- **Haxe**: Build toolchain conflicts with `-fmodules` / `-fcxx-modules`
- **Custom build systems**: May not support module imports

With modules disabled:

- `@import Sentry` does not work (requires modules)
- `#import <Sentry/Sentry.h>` exposes only ObjC headers, not Swift APIs
- `#import <Sentry/Sentry-Swift.h>` fails with forward declaration errors in `.mm` files

**Result:** `SentrySDK`, `SentryOptions`, `options.sessionReplay` and other Swift-bridged APIs are unavailable from ObjC++ without modules.

## Solution

SentryObjC provides a three-tier architecture:

```
┌─────────────────────────────────────────────────────────┐
│ SentryObjC (Pure Objective-C)                           │
│                                                         │
│ Public headers: SentrySDK.h, SentryOptions.h, etc.      │
│ Implementation: .m files that call the bridge           │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ SentryObjCBridge (Swift)                                │
│                                                         │
│ @objc methods callable from ObjC                        │
│ Converts wrapper types ↔ real SDK types                 │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Sentry SDK (Full implementation)                        │
│                                                         │
│ SentrySwift, SentryObjCInternal, SentryCrash, etc.      │
└─────────────────────────────────────────────────────────┘
```

## Type Architecture

SentryObjC defines its own types that mirror the main SDK:

| SentryObjC Type    | Wraps                   |
| ------------------ | ----------------------- |
| `SentrySDK`        | Real `SentrySDK`        |
| `SentryOptions`    | Real `SentryOptions`    |
| `SentryUser`       | Real `SentryUser`       |
| `SentryBreadcrumb` | Real `SentryBreadcrumb` |
| `SentryScope`      | Real `SentryScope`      |
| ...                | ...                     |

Each wrapper type:

1. Is a complete `@interface` definition (pure ObjC, no Swift imports)
2. Holds an internal reference to the real SDK type
3. Exposes the same properties/methods
4. Bridges through `SentryObjCBridge` for conversions

## Source Layout

```
Sources/
├── SentryObjC/
│   ├── Public/
│   │   ├── SentryObjC.h          # Umbrella header
│   │   ├── SentrySDK.h           # @interface SentrySDK
│   │   ├── SentryOptions.h       # @interface SentryOptions
│   │   ├── SentryUser.h          # @interface SentryUser
│   │   └── ...                   # All public types
│   ├── SentrySDK.m               # Implementation
│   ├── SentryOptions.m
│   └── ...
├── SentryObjCBridge/
│   └── SentryObjCBridge.swift    # @objc bridge methods
```

## Distribution

### SPM

The `SentryObjC` product in `Package.swift` includes all three tiers:

```swift
.library(name: "SentryObjC", targets: ["SentryObjCInternal", "SentryObjCBridge", "SentryObjC"])
```

### XCFramework

`SentryObjC.xcframework` bundles everything into a single framework:

- All platforms: iOS, macOS, Catalyst, tvOS, watchOS, visionOS
- Pure ObjC public headers (no `Sentry-Swift.h`)
- Single binary containing wrapper + bridge + full SDK

## Usage

```objc
// In .mm file with CLANG_ENABLE_MODULES=NO
#import <SentryObjC/SentryObjC.h>

[SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
    options.dsn = @"https://...";
    options.debug = YES;
    options.tracesSampleRate = @1.0;

    // Swift APIs work!
    options.sessionReplay.sessionSampleRate = 0;
    options.sessionReplay.onErrorSampleRate = 1;
}];
```

## Building

```bash
# Build for iOS simulator (development)
make build-sentryobjc

# Build full xcframework (all platforms)
make build-sentryobjc-xcframework
```

## Design Decisions

### Why same type names?

Using `SentryOptions` instead of `SentryObjCOptions` provides a familiar API for developers. Since `SentryObjC.xcframework` is standalone (doesn't link against `Sentry.xcframework`), there's no symbol collision.

### Why not just fix the Swift headers?

The `Sentry-Swift.h` generated header has inherent issues when included from ObjC++ without modules. Forward declarations for UIKit types (`UIView`, `UIWindowLevel`) fail. This is a limitation of the Swift-to-ObjC bridging, not something we can easily fix.

### Why embed the full SDK?

Embedding the full SDK in `SentryObjC.xcframework` (vs. depending on `Sentry.xcframework`) provides:

- Single framework to link
- No transitive dependency management
- No risk of version mismatches

## Related

- [Issue #6342](https://github.com/getsentry/sentry-cocoa/issues/6342) - Original feature request
- [Issue #4543](https://github.com/getsentry/sentry-cocoa/issues/4543) - Problem documentation
- `Samples/iOS-ObjectiveCpp-NoModules/` - Sample app demonstrating usage
