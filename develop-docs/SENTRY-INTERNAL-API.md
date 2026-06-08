# SentrySD c.internal — Structured Hybrid SDK API

**Date:** 2026-06-08
**Issue:** [#7881](https://github.com/getsentry/sentry-cocoa/issues/7881)
**Contributors:** @philprime

## Problem

Hybrid SDKs (React Native, Flutter, .NET, Unity) consume `PrivateSentrySDKOnly`, a flat Objective-C class with 30+ static methods spanning unrelated subsystems. This causes three problems:

1. **Build coupling.** Hybrid SDKs must add `${PODS_ROOT}/Sentry/Sources/Sentry/include` to their header search paths and `#import <Sentry/PrivateSentrySDKOnly.h>`. This blocks migration to SPM `binaryTarget` or pre-built `.xcframework` consumption, because those distribution channels don't expose private header search paths.

2. **Flat namespace.** All methods live on one class with no grouping. `captureReplay`, `startProfilerForTrace:`, `currentScreenFrames`, `envelopeWithData:`, and `setSdkName:` all share the same scope, making the API hard to discover and reason about.

3. **Naming is a workaround, not a contract.** The class name is intentionally ugly ("private...only") to discourage use, but there's no real access restriction. Any consumer can import it.

## Design Goals

1. **Structured, namespaced API.** Group methods by integration area with sub-objects: `SentrySDK.internal.replay`, `SentrySDK.internal.profiling`, etc.
2. **Pure Swift.** The `SentrySDK.internal` API is Swift-only. No `@objc` annotations, no `NSObject` inheritance on the internal API types. Objective-C consumers use the ObjC wrapper SDK (`SentryObjCSDK.internal`).
3. **Always available.** `SentrySDK.internal` is a static property that works before and after `SentrySDK.start()`. Sub-object methods that require a running SDK return nil or no-op, matching current `PrivateSentrySDKOnly` behavior.
4. **Deprecate, don't remove.** `PrivateSentrySDKOnly` gets deprecation annotations but keeps its own implementation for at least one major version. It does not delegate to the new types (since they're pure Swift and it's ObjC).
5. **Single PR.** All sub-objects and deprecations ship in one PR.

## Non-Goals

- Removing `PrivateSentrySDKOnly` (future major version).
- Wrapping types already available in the public API (e.g., `SentrySDK.replay` for end users).
- Changing the internal SDK architecture. The new types call the same internal code that `PrivateSentrySDKOnly` does today.

## Architecture

```
Swift consumers:    SentrySDK.internal.replay.capture()
                          |
                    SentryInternalApi (pure Swift)
                          |
                    SentryInternalReplayApi, etc. (pure Swift)
                          |
                    SDK internals (SentryDependencyContainer, SentryHub, etc.)

ObjC consumers:     [[SentryObjCSDK internal] replay].capture
                          |
                    SentryObjCInternalApi (@objc wrapper)
                          |
                    SentryObjCInternalReplayApi, etc. (@objc wrappers)
                          |
                    SDK internals (same path)

Deprecated path:    [PrivateSentrySDKOnly captureReplay]
                          |
                    SDK internals (same path, independent impl)
```

All three paths converge on the same SDK internals. The new Swift types and the deprecated ObjC class are independent implementations that call the same underlying code.

## API Grouping

Methods are grouped by integration area, following the model established in PR [#8017](https://github.com/getsentry/sentry-cocoa/pull/8017).

### `SentrySDK.internal` (root — `SentryInternalApi`)

Direct methods (no natural integration group):

| Method                                       | Replaces                                                       |
| -------------------------------------------- | -------------------------------------------------------------- |
| `userWithDictionary(_:) -> User`             | `PrivateSentrySDKOnly.userWithDictionary:`                     |
| `breadcrumbWithDictionary(_:) -> Breadcrumb` | `PrivateSentrySDKOnly.breadcrumbWithDictionary:`               |
| `setTrace(_:spanId:)`                        | `PrivateSentrySDKOnly.setTrace:spanId:`                        |
| `setLogOutput(_:)`                           | `PrivateSentrySDKOnly.setLogOutput:`                           |
| `ignoreNextSignal(_:)`                       | `PrivateSentrySDKOnly.ignoreNextSignal:`                       |
| `setSdkName(_:version:)`                     | `PrivateSentrySDKOnly.setSdkName:andVersionString:`            |
| `setSdkName(_:)`                             | `PrivateSentrySDKOnly.setSdkName:`                             |
| `sdkName: String`                            | `PrivateSentrySDKOnly.getSdkName`                              |
| `sdkVersionString: String`                   | `PrivateSentrySDKOnly.getSdkVersionString`                     |
| `addSdkPackage(name:version:)`               | `PrivateSentrySDKOnly.addSdkPackage:version:`                  |
| `extraContext: [String: Any]`                | `PrivateSentrySDKOnly.getExtraContext`                         |
| `installationID: String`                     | `PrivateSentrySDKOnly.installationID`                          |
| `options: Options`                           | `PrivateSentrySDKOnly.options`                                 |
| `options(fromDictionary:) throws -> Options` | `PrivateSentrySDKOnly.optionsWithDictionary:didFailWithError:` |
| `debugImages: [DebugMeta]`                   | `PrivateSentrySDKOnly.getDebugImages`                          |

Sub-object accessors:

| Property        | Type                             | Platform guard                      |
| --------------- | -------------------------------- | ----------------------------------- |
| `replay`        | `SentryInternalReplayApi`        | `SENTRY_TARGET_REPLAY_SUPPORTED`    |
| `profiling`     | `SentryInternalProfilingApi`     | `SENTRY_TARGET_PROFILING_SUPPORTED` |
| `appStart`      | `SentryInternalAppStartApi`      | `SENTRY_UIKIT_AVAILABLE`            |
| `performance`   | `SentryInternalPerformanceApi`   | `SENTRY_UIKIT_AVAILABLE`            |
| `screenshot`    | `SentryInternalScreenshotApi`    | `SENTRY_UIKIT_AVAILABLE`            |
| `viewHierarchy` | `SentryInternalViewHierarchyApi` | `SENTRY_UIKIT_AVAILABLE`            |
| `envelope`      | `SentryInternalEnvelopeApi`      | none                                |
| `screen`        | `SentryInternalScreenApi`        | `SENTRY_UIKIT_AVAILABLE`            |

### `SentrySDK.internal.replay` — `SentryInternalReplayApi`

| Method                                               | Replaces                                            |
| ---------------------------------------------------- | --------------------------------------------------- |
| `configure(breadcrumbConverter:screenshotProvider:)` | `configureSessionReplayWith:screenshotProvider:`    |
| `capture() -> Bool`                                  | `captureReplay` + `getReplayIntegration` (see note) |
| `replayId: String?`                                  | `getReplayId`                                       |
| `addIgnoreClasses(_:)`                               | `addReplayIgnoreClasses:`                           |
| `addRedactClasses(_:)`                               | `addReplayRedactClasses:`                           |
| `setIgnoreContainerClass(_:)`                        | `setIgnoreContainerClass:`                          |
| `setRedactContainerClass(_:)`                        | `setRedactContainerClass:`                          |
| `setTags(_:)`                                        | `setReplayTags:`                                    |

> **Note on `capture() -> Bool`:** React Native currently works around `captureReplay` being `void` by dynamically calling `getReplayIntegration` via `performSelector:` to access the integration's `captureReplay` which returns `BOOL`. The new API makes `capture()` return `Bool` directly, eliminating both the void limitation and the dynamic dispatch hack. `getReplayIntegration` is intentionally not exposed — callers should not need the integration object.

> **Note on `debugImages`:** Flutter calls `PrivateSentrySDKOnly.getDebugImages()` to retrieve debug meta images for symbolication. This method is not declared in the current `PrivateSentrySDKOnly.h` header (it's available via `@_spi(Private)`) but is a real call site that needs a home. It lives directly on `.internal` rather than in a sub-object since it doesn't belong to any integration group.

### `SentrySDK.internal.profiling` — `SentryInternalProfilingApi`

| Method                                        | Replaces                              |
| --------------------------------------------- | ------------------------------------- |
| `start(for traceId:) -> UInt64`               | `startProfilerForTrace:`              |
| `collect(between:and:for:) -> [String: Any]?` | `collectProfileBetween:and:forTrace:` |
| `discard(for traceId:)`                       | `discardProfilerForTrace:`            |

### `SentrySDK.internal.appStart` — `SentryInternalAppStartApi`

| Method                                                            | Replaces                           |
| ----------------------------------------------------------------- | ---------------------------------- |
| `hybridSDKMode: Bool`                                             | `appStartMeasurementHybridSDKMode` |
| `measurement: SentryAppStartMeasurement?`                         | `appStartMeasurement`              |
| `measurementWithSpans: [String: Any]?`                            | `appStartMeasurementWithSpans`     |
| `onMeasurementAvailable: ((SentryAppStartMeasurement?) -> Void)?` | `onAppStartMeasurementAvailable`   |

### `SentrySDK.internal.performance` — `SentryInternalPerformanceApi`

| Method                                    | Replaces                                 |
| ----------------------------------------- | ---------------------------------------- |
| `framesTrackingHybridSDKMode: Bool`       | `framesTrackingMeasurementHybridSDKMode` |
| `isFramesTrackingRunning: Bool`           | `isFramesTrackingRunning`                |
| `currentScreenFrames: SentryScreenFrames` | `currentScreenFrames`                    |

### `SentrySDK.internal.screenshot` — `SentryInternalScreenshotApi`

| Method                 | Replaces             |
| ---------------------- | -------------------- |
| `capture() -> [Data]?` | `captureScreenshots` |

### `SentrySDK.internal.viewHierarchy` — `SentryInternalViewHierarchyApi`

| Method               | Replaces               |
| -------------------- | ---------------------- |
| `capture() -> Data?` | `captureViewHierarchy` |

### `SentrySDK.internal.envelope` — `SentryInternalEnvelopeApi`

| Method                                  | Replaces            |
| --------------------------------------- | ------------------- |
| `store(_:)`                             | `storeEnvelope:`    |
| `capture(_:)`                           | `captureEnvelope:`  |
| `deserialize(from:) -> SentryEnvelope?` | `envelopeWithData:` |

### `SentrySDK.internal.screen` — `SentryInternalScreenApi`

| Method           | Replaces            |
| ---------------- | ------------------- |
| `setCurrent(_:)` | `setCurrentScreen:` |

## Swift Implementation Pattern

Each sub-object is a plain Swift class (no `NSObject`, no `@objc`):

```swift
// Sources/Swift/HybridSDK/SentryInternalApi.swift

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
public final class SentryInternalApi {
    @_implementationOnly import _SentryPrivate

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    public let replay = SentryInternalReplayApi()
    #endif

    public let envelope = SentryInternalEnvelopeApi()

    // ... other sub-objects ...

    public func setSdkName(_ name: String, version: String) {
        SentryMeta.sdkName = name
        SentryMeta.versionString = version
    }

    // ... direct methods ...
}
```

```swift
// Sources/Swift/HybridSDK/SentryInternalReplayApi.swift

public final class SentryInternalReplayApi {
    public func capture() {
        // Same internal call as PrivateSentrySDKOnly.captureReplay
        SentrySessionReplayIntegration.captureReplay()
    }

    public var replayId: String? {
        SentrySessionReplayIntegration.getReplayId()
    }

    // ... other methods ...
}
```

The `SentrySDK` extension:

```swift
// Sources/Swift/Helper/SentrySDK+Internal.swift

extension SentrySDK {
    /// APIs for hybrid SDKs (React Native, Flutter, .NET, Unity).
    ///
    /// These APIs may change in any minor release without deprecation.
    /// App developers should use the standard `SentrySDK` API instead.
    public static let `internal` = SentryInternalApi()
}
```

## ObjC Wrapper Pattern

Following the two-target architecture from [SENTRY-OBJC.md](SENTRY-OBJC.md):

**Header** (`Sources/SentryObjC/Public/SentryObjCInternalApi.h`):

```objc
#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCDefines.h>

@class SentryObjCInternalReplayApi;
@class SentryObjCInternalEnvelopeApi;
// ... other forward declarations ...

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard @c SentryObjCSDK API surface instead.
@interface SentryObjCInternalApi : NSObject

#if SENTRY_OBJC_REPLAY_SUPPORTED
@property (nonatomic, readonly) SentryObjCInternalReplayApi *replay;
#endif

@property (nonatomic, readonly) SentryObjCInternalEnvelopeApi *envelope;

// ... direct methods ...
- (void)setSdkName:(NSString *)name version:(NSString *)version;
- (NSString *)sdkName;
- (NSString *)sdkVersionString;

@end
```

**Wrapper** (`Sources/SentryObjCCompat/SentryObjCInternalApi.swift`):

```swift
@objc(SentryObjCInternalApi) public final class SentryObjCInternalApi: NSObject {
    internal let wrapped = SentrySDK.`internal`

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    @objc public var replay: SentryObjCInternalReplayApi {
        SentryObjCInternalReplayApi(wrapped.replay)
    }
    #endif

    @objc public var envelope: SentryObjCInternalEnvelopeApi {
        SentryObjCInternalEnvelopeApi(wrapped.envelope)
    }

    @objc public func setSdkName(_ name: String, version: String) {
        wrapped.setSdkName(name, version: version)
    }

    // ... other delegating methods ...
}
```

**SentryObjCSDK extension** (`Sources/SentryObjCCompat/SentryObjCSDK+Internal.swift`):

```swift
extension SentryObjCSDK {
    @objc public static let `internal` = SentryObjCInternalApi()
}
```

Each sub-object follows the same header + wrapper pair pattern. See [SENTRY-OBJC.md](SENTRY-OBJC.md) for the full wrapper conventions.

## Deprecation Strategy

All methods on `PrivateSentrySDKOnly` receive deprecation annotations pointing to the new API:

```objc
// PrivateSentrySDKOnly.h
+ (void)captureReplay
    __attribute__((deprecated("Use SentrySDK.internal.replay.capture() (Swift) "
                              "or [[SentryObjCSDK internal].replay capture] (ObjC)")));
```

`PrivateSentrySDKOnly` retains its own implementation (does not delegate to the new Swift types). Both paths call the same SDK internals independently. Removal happens in the next major version.

## Type Inventory

| Swift type                       | ObjC header                            | ObjC wrapper                               | Platform   |
| -------------------------------- | -------------------------------------- | ------------------------------------------ | ---------- |
| `SentryInternalApi`              | `SentryObjCInternalApi.h`              | `SentryObjCInternalApi.swift`              | all        |
| `SentryInternalReplayApi`        | `SentryObjCInternalReplayApi.h`        | `SentryObjCInternalReplayApi.swift`        | iOS, tvOS  |
| `SentryInternalProfilingApi`     | `SentryObjCInternalProfilingApi.h`     | `SentryObjCInternalProfilingApi.swift`     | iOS, macOS |
| `SentryInternalAppStartApi`      | `SentryObjCInternalAppStartApi.h`      | `SentryObjCInternalAppStartApi.swift`      | iOS, tvOS  |
| `SentryInternalPerformanceApi`   | `SentryObjCInternalPerformanceApi.h`   | `SentryObjCInternalPerformanceApi.swift`   | iOS, tvOS  |
| `SentryInternalScreenshotApi`    | `SentryObjCInternalScreenshotApi.h`    | `SentryObjCInternalScreenshotApi.swift`    | iOS, tvOS  |
| `SentryInternalViewHierarchyApi` | `SentryObjCInternalViewHierarchyApi.h` | `SentryObjCInternalViewHierarchyApi.swift` | iOS, tvOS  |
| `SentryInternalEnvelopeApi`      | `SentryObjCInternalEnvelopeApi.h`      | `SentryObjCInternalEnvelopeApi.swift`      | all        |
| `SentryInternalScreenApi`        | `SentryObjCInternalScreenApi.h`        | `SentryObjCInternalScreenApi.swift`        | iOS, tvOS  |

**Total:** 9 Swift types + 9 ObjC headers + 9 ObjC wrappers = 27 new files.

## File Layout

```
Sources/
├── Swift/
│   └── HybridSDK/
│       ├── SentryInternalApi.swift
│       ├── SentryInternalReplayApi.swift
│       ├── SentryInternalProfilingApi.swift
│       ├── SentryInternalAppStartApi.swift
│       ├── SentryInternalPerformanceApi.swift
│       ├── SentryInternalScreenshotApi.swift
│       ├── SentryInternalViewHierarchyApi.swift
│       ├── SentryInternalEnvelopeApi.swift
│       └── SentryInternalScreenApi.swift
├── Swift/Helper/
│   └── SentrySDK+Internal.swift              # extension adding .internal
├── SentryObjC/Public/
│   ├── SentryObjCInternalApi.h
│   ├── SentryObjCInternalReplayApi.h
│   ├── SentryObjCInternalProfilingApi.h
│   ├── SentryObjCInternalAppStartApi.h
│   ├── SentryObjCInternalPerformanceApi.h
│   ├── SentryObjCInternalScreenshotApi.h
│   ├── SentryObjCInternalViewHierarchyApi.h
│   ├── SentryObjCInternalEnvelopeApi.h
│   └── SentryObjCInternalScreenApi.h
├── SentryObjCCompat/
│   ├── SentryObjCInternalApi.swift
│   ├── SentryObjCInternalReplayApi.swift
│   ├── SentryObjCInternalProfilingApi.swift
│   ├── SentryObjCInternalAppStartApi.swift
│   ├── SentryObjCInternalPerformanceApi.swift
│   ├── SentryObjCInternalScreenshotApi.swift
│   ├── SentryObjCInternalViewHierarchyApi.swift
│   ├── SentryObjCInternalEnvelopeApi.swift
│   ├── SentryObjCInternalScreenApi.swift
│   └── SentryObjCSDK+Internal.swift
```

## Documentation

Every type and method carries a headerdoc/docstring with this preamble:

> APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
> These methods are public for consumption by wrapper SDKs that bridge between native and managed runtimes. They may change, be renamed, or be removed in any minor release without prior deprecation.
> App developers: prefer the standard `SentrySDK` API surface instead.

Individual methods carry per-method documentation explaining parameters and behavior, ported from the existing `PrivateSentrySDKOnly` headerdocs.

## Call-Site Migration Examples

### Swift (hybrid SDK)

```swift
// Before
import Sentry
PrivateSentrySDKOnly.setSdkName("sentry.cocoa.react-native", andVersionString: "6.0.0")
PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
let frames = PrivateSentrySDKOnly.currentScreenFrames
PrivateSentrySDKOnly.captureReplay()

// After
import Sentry
SentrySDK.internal.setSdkName("sentry.cocoa.react-native", version: "6.0.0")
SentrySDK.internal.appStart.hybridSDKMode = true
let frames = SentrySDK.internal.performance.currentScreenFrames
let success = SentrySDK.internal.replay.capture()
```

### ObjC (hybrid SDK via SentryObjC wrapper)

```objc
// Before
#import <Sentry/PrivateSentrySDKOnly.h>
[PrivateSentrySDKOnly setSdkName:@"sentry.cocoa.react-native" andVersionString:@"6.0.0"];
PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = YES;
SentryScreenFrames *frames = PrivateSentrySDKOnly.currentScreenFrames;
[PrivateSentrySDKOnly captureReplay];
// Workaround to get BOOL result:
id integration = [PrivateSentrySDKOnly performSelector:@selector(getReplayIntegration)];

// After
#import <SentryObjC/SentryObjC.h>
[[SentryObjCSDK internal] setSdkName:@"sentry.cocoa.react-native" version:@"6.0.0"];
[SentryObjCSDK internal].appStart.hybridSDKMode = YES;
SentryObjCScreenFrames *frames = [SentryObjCSDK internal].performance.currentScreenFrames;
BOOL success = [[[SentryObjCSDK internal] replay] capture];
```

## Public API Surface Impact

- `sdk_api.json` gains ~50 new public symbols (9 types + their methods/properties).
- `sdk_api_objc.json` gains ~50 new symbols (9 ObjC types + methods).
- `PrivateSentrySDKOnly` methods gain `deprecated` annotations (no removal, no ABI break).
- `make generate-public-api` must be run and committed.

## Testing

- One ObjC integration test file per sub-object in `Tests/SentryObjCTests/` verifying the ObjC wrapper compiles and delegates correctly.
- Swift unit tests in `Tests/SentryTests/HybridSDK/` for each `SentryInternal*Api` type, covering the same scenarios as existing `PrivateSentrySDKOnlyTests.swift`.
- Verify `PrivateSentrySDKOnly` deprecation warnings compile cleanly (no errors, only warnings).

## Open Questions

1. **`SentryObjCSDK.internal` naming in ObjC.** `internal` is not a reserved word in ObjC, so no conflict. But should we verify no collision with Apple's runtime selectors?
2. **Thread safety.** `PrivateSentrySDKOnly` methods are individually thread-safe via internal SDK locks. The new types delegate to the same internals, inheriting the same guarantees. Should we add `@Sendable` annotations to callback parameters?
3. **`SentryInternalApi` as singleton vs. value.** Currently proposed as `static let` (singleton). If the SDK is closed and re-started, the sub-objects still point to the same instances. This matches current `PrivateSentrySDKOnly` behavior (static methods, no instance state) but worth confirming.
