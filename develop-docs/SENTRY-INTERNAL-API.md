# SentrySDK.internal — Structured Hybrid SDK API

**Date:** 2026-06-08
**Issue:** [#7881](https://github.com/getsentry/sentry-cocoa/issues/7881)
**Contributors:** @philprime

## Problem

Hybrid SDKs (React Native, Flutter, .NET, Unity) consumed `PrivateSentrySDKOnly`, a flat Objective-C class with 30+ static methods spanning unrelated subsystems. This caused three problems:

1. **Build coupling.** Hybrid SDKs had to add `${PODS_ROOT}/Sentry/Sources/Sentry/include` to their header search paths and `#import <Sentry/PrivateSentrySDKOnly.h>`. This blocked migration to SPM `binaryTarget` or pre-built `.xcframework` consumption, because those distribution channels don't expose private header search paths.

2. **Flat namespace.** All methods lived on one class with no grouping. `captureReplay`, `startProfilerForTrace:`, `currentScreenFrames`, `envelopeWithData:`, and `setSdkName:` all shared the same scope, making the API hard to discover and reason about.

3. **Naming is a workaround, not a contract.** The class name was intentionally ugly ("private...only") to discourage use, but there was no real access restriction. Any consumer could import it.

## Design Goals

1. **Structured, namespaced API.** Methods are grouped by integration area with sub-objects: `SentrySDK.internal.replay`, `SentrySDK.internal.profiling`, etc.
2. **Pure Swift, public API.** The `SentrySDK.internal` API is Swift-only. No `@objc` annotations, no `NSObject` inheritance on the internal API types. All types are `public` — **not** gated behind `@_spi(Private)`. Hybrid SDK consumers and regular SDK users are treated as equal citizens; hybrid SDKs simply get additional functionality through `SentrySDK.internal`. Objective-C consumers use the ObjC wrapper SDK (`SentryObjCSDK.internal`).
3. **Always available.** `SentrySDK.internal` is a lazy `var` property (protected by `NSRecursiveLock`) that works before and after `SentrySDK.start()`. It is reset on SDK close via `resetInternalApi()`. Sub-object methods that require a running SDK return nil or no-op, matching previous `PrivateSentrySDKOnly` behavior.
4. **Deprecate, don't remove.** `PrivateSentrySDKOnly` received deprecation annotations but keeps its own implementation for at least one major version. It does not delegate to the new types (since they're pure Swift and it's ObjC).

## Non-Goals

- Removing `PrivateSentrySDKOnly` (deferred to a future major version).
- Wrapping types already available in the public API (e.g., `SentrySDK.replay` for end users).
- Changing the internal SDK architecture. The new types call the same internal code that `PrivateSentrySDKOnly` did.

## Eliminated Internal Header Imports

Beyond replacing `PrivateSentrySDKOnly`, this API also eliminated the need for hybrid SDKs to import other internal headers:

### `SentryOptionsInternal.h`

Unity imported this solely for `+initWithDict:didFailWithError:`, which creates `SentryOptions` from a dictionary passed across the C#→ObjC bridge. This is now mapped to `.internal.options(fromDictionary:)` / `[[… internal] optionsFromDictionary:error:]`.

### `SentrySwizzle.h`

React Native imported this for the `SentrySwizzleInstanceMethod` macro to swizzle `viewDidAppear:` on `RNSScreen` for frame tracking. The macro API was tightly coupled to the internal implementation (factory blocks, `SentrySwizzleInfo`, IMP casting).

The new API's `SentrySDK.internal.swizzle.instanceMethod(_:in:mode:key:factory:)` / `[[[SentryObjCSDK internal] swizzle] swizzleInstanceMethod:inClass:newImpFactory:mode:key:]` wraps the same underlying `SentrySwizzle` mechanism behind a stable method call. Hybrid SDKs no longer need the header search path or macro definitions.

### `Sentry-Swift.h`

Unity imported this to access `SentryId` and `SentrySpanId` types, which are Swift classes only available to ObjC through the auto-generated bridging header. The Unity code even documented the workaround: _"This is a workaround to deal with SentryId living inside the Swift header."_ It used `NSClassFromString()` to load these types dynamically.

With the new API, `SentryObjCInternalApi.setTrace:spanId:` accepts `SentryObjCId *` and `SentryObjCSpanId *` parameters — types that already exist in the `SentryObjC` public headers. Unity imports `<SentryObjC/SentryObjC.h>` instead, which provides both the internal API and the ID types.

### Result

After migration, hybrid SDKs need only one import:

- **Swift:** `import Sentry`
- **ObjC:** `#import <SentryObjC/SentryObjC.h>`

No more `PrivateSentrySDKOnly.h`, `SentryOptionsInternal.h`, `Sentry-Swift.h`, or `SentrySwizzle.h`.

## Architecture

```
Swift consumers:    SentrySDK.internal.replay.capture()
                          |
                    SentryInternalApi (public, pure Swift)
                          |
                    SentryInternalReplayApi, etc. (public, pure Swift)
                          |  (dependency injection via provider protocols)
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

Methods are grouped by integration area, following the model established in PR [#8017](https://github.com/getsentry/sentry-cocoa/pull/8017). The "Replaced" column in the tables below shows which deprecated `PrivateSentrySDKOnly` method each new method supersedes.

### `SentrySDK.internal` (root — `SentryInternalApi`)

Direct methods (no natural integration group):

| Method                                       | Replaced                                                       |
| -------------------------------------------- | -------------------------------------------------------------- |
| `setTrace(_:spanId:)`                        | `PrivateSentrySDKOnly.setTrace:spanId:`                        |
| `setLogOutput(_:)`                           | `PrivateSentrySDKOnly.setLogOutput:`                           |
| `ignoreNextSignal(_:)`                       | `PrivateSentrySDKOnly.ignoreNextSignal:`                       |
| `options: Options`                           | `PrivateSentrySDKOnly.options`                                 |
| `options(fromDictionary:) throws -> Options` | `PrivateSentrySDKOnly.optionsWithDictionary:didFailWithError:` |

Sub-object accessors:

| Property        | Type                             | Platform guard                      |
| --------------- | -------------------------------- | ----------------------------------- |
| `replay`        | `SentryInternalReplayApi`        | `SENTRY_UIKIT_AVAILABLE`            |
| `profiling`     | `SentryInternalProfilingApi`     | `SENTRY_TARGET_PROFILING_SUPPORTED` |
| `appStart`      | `SentryInternalAppStartApi`      | none                                |
| `performance`   | `SentryInternalPerformanceApi`   | `SENTRY_UIKIT_AVAILABLE`            |
| `screenshot`    | `SentryInternalScreenshotApi`    | `SENTRY_UIKIT_AVAILABLE`            |
| `viewHierarchy` | `SentryInternalViewHierarchyApi` | `SENTRY_UIKIT_AVAILABLE`            |
| `envelope`      | `SentryInternalEnvelopeApi`      | none                                |
| `screen`        | `SentryInternalScreenApi`        | `SENTRY_UIKIT_AVAILABLE`            |
| `swizzle`       | `SentryInternalSwizzleApi`       | none                                |
| `sdk`           | `SentryInternalSdkApi`           | none                                |
| `debug`         | `SentryInternalDebugApi`         | none                                |
| `breadcrumbs`   | `SentryInternalBreadcrumbApi`    | none                                |
| `user`          | `SentryInternalUserApi`          | none                                |

### `SentrySDK.internal.replay` — `SentryInternalReplayApi`

| Method                                               | Replaced                                            |
| ---------------------------------------------------- | --------------------------------------------------- |
| `configure(breadcrumbConverter:screenshotProvider:)` | `configureSessionReplayWith:screenshotProvider:`    |
| `capture() -> Bool`                                  | `captureReplay` + `getReplayIntegration` (see note) |
| `replayId: String?`                                  | `getReplayId`                                       |
| `addIgnoreClasses(_:)`                               | `addReplayIgnoreClasses:`                           |
| `addRedactClasses(_:)`                               | `addReplayRedactClasses:`                           |
| `setIgnoreContainerClass(_:)`                        | `setIgnoreContainerClass:`                          |
| `setRedactContainerClass(_:)`                        | `setRedactContainerClass:`                          |
| `setTags(_:)`                                        | `setReplayTags:`                                    |

> **Note on `capture() -> Bool`:** React Native previously worked around `captureReplay` being `void` by dynamically calling `getReplayIntegration` via `performSelector:` to access the integration's `captureReplay` which returns `BOOL`. The new API returns `Bool` directly, eliminating both the void limitation and the dynamic dispatch hack. `getReplayIntegration` is intentionally not exposed — callers should not need the integration object.

### `SentrySDK.internal.profiling` — `SentryInternalProfilingApi`

| Method                                        | Replaced                              |
| --------------------------------------------- | ------------------------------------- |
| `start(for traceId:) -> UInt64`               | `startProfilerForTrace:`              |
| `collect(between:and:for:) -> [String: Any]?` | `collectProfileBetween:and:forTrace:` |
| `discard(for traceId:)`                       | `discardProfilerForTrace:`            |

### `SentrySDK.internal.appStart` — `SentryInternalAppStartApi`

| Method                                                            | Replaced                           | Platform guard           |
| ----------------------------------------------------------------- | ---------------------------------- | ------------------------ |
| `hybridSDKMode: Bool`                                             | `appStartMeasurementHybridSDKMode` | none                     |
| `measurementWithSpans: [String: Any]?`                            | `appStartMeasurementWithSpans`     | none                     |
| `measurement: SentryAppStartMeasurement?`                         | `appStartMeasurement`              | `SENTRY_UIKIT_AVAILABLE` |
| `onMeasurementAvailable: ((SentryAppStartMeasurement?) -> Void)?` | `onAppStartMeasurementAvailable`   | `SENTRY_UIKIT_AVAILABLE` |

### `SentrySDK.internal.performance` — `SentryInternalPerformanceApi`

| Method                                    | Replaced                                 |
| ----------------------------------------- | ---------------------------------------- |
| `framesTrackingHybridSDKMode: Bool`       | `framesTrackingMeasurementHybridSDKMode` |
| `isFramesTrackingRunning: Bool`           | `isFramesTrackingRunning`                |
| `currentScreenFrames: SentryScreenFrames` | `currentScreenFrames`                    |

### `SentrySDK.internal.screenshot` — `SentryInternalScreenshotApi`

| Method                 | Replaced             |
| ---------------------- | -------------------- |
| `capture() -> [Data]?` | `captureScreenshots` |

### `SentrySDK.internal.viewHierarchy` — `SentryInternalViewHierarchyApi`

| Method               | Replaced               |
| -------------------- | ---------------------- |
| `capture() -> Data?` | `captureViewHierarchy` |

### `SentrySDK.internal.envelope` — `SentryInternalEnvelopeApi`

| Method                                  | Replaced            |
| --------------------------------------- | ------------------- |
| `store(_:)`                             | `storeEnvelope:`    |
| `capture(_:)`                           | `captureEnvelope:`  |
| `deserialize(from:) -> SentryEnvelope?` | `envelopeWithData:` |

### `SentrySDK.internal.screen` — `SentryInternalScreenApi`

| Method           | Replaced            |
| ---------------- | ------------------- |
| `setCurrent(_:)` | `setCurrentScreen:` |

### `SentrySDK.internal.swizzle` — `SentryInternalSwizzleApi`

Replaced the direct import of `SentrySwizzle.h` and its macro-based API (`SentrySwizzleInstanceMethod`, `SentrySWReturnType`, etc.).

| Method                                           | Replaced                            |
| ------------------------------------------------ | ----------------------------------- |
| `instanceMethod(_:in:mode:key:factory:) -> Bool` | `SentrySwizzleInstanceMethod` macro |

The factory block receives a closure that returns the original `IMP`. The caller returns a new block (cast to `id`) that becomes the replacement implementation. This matches the underlying `SentrySwizzle` factory pattern but without requiring the header or macro definitions.

**Mode enum** (`SentryInternalSwizzleApi.Mode`):

| Case                           | Behavior                                                           |
| ------------------------------ | ------------------------------------------------------------------ |
| `.always`                      | Swizzle every time, even if already swizzled                       |
| `.oncePerClass`                | Swizzle only once per class (recommended default)                  |
| `.oncePerClassAndSuperclasses` | Swizzle only if neither this class nor any superclass was swizzled |

> **Why not a simplified "before/after hook" API?** The factory-based API preserves full flexibility (custom argument handling, conditional forwarding, return value modification) at the cost of the caller doing IMP casting. A convenience wrapper can be added later if multiple hybrid SDKs converge on a simpler pattern.

### `SentrySDK.internal.sdk` — `SentryInternalSdkApi`

| Method                        | Replaced                                            |
| ----------------------------- | --------------------------------------------------- |
| `name: String`                | `PrivateSentrySDKOnly.getSdkName` / `.setSdkName:`  |
| `versionString: String`       | `PrivateSentrySDKOnly.getSdkVersionString`          |
| `setName(_:version:)`         | `PrivateSentrySDKOnly.setSdkName:andVersionString:` |
| `addPackage(name:version:)`   | `PrivateSentrySDKOnly.addSdkPackage:version:`       |
| `extraContext: [String: Any]` | `PrivateSentrySDKOnly.getExtraContext`              |
| `installationID: String`      | `PrivateSentrySDKOnly.installationID`               |
| `installedIntegrationNames: Set<String>` | `PrivateSentrySDKOnly.options.integrations` (see note) |
| `trimmedInstalledIntegrationNames: [String]` | (none — see note) |

`name` and `versionString` are read-write properties — the getter and setter replace both the get/set static methods.

> **Note on `installedIntegrationNames`:** Flutter and other hybrid SDKs previously read `PrivateSentrySDKOnly.options.integrations` to append native integration names to event `sdk` payloads. `Options.integrations` was removed in v9 ([#6492](https://github.com/getsentry/sentry-cocoa/pull/6492)); it held configured integration class names, not the runtime installed set. `installedIntegrationNames` returns the class names currently registered on `SentryHub` (e.g. `SentryANRTrackingIntegration`). Returns an empty set before `SentrySDK.start()` or after `SentrySDK.close()`.
>
> **Note on `trimmedInstalledIntegrationNames`:** The event `sdk.integrations` field uses shortened names (e.g. `ANRTracking` instead of `SentryANRTrackingIntegration`). Hybrid SDKs that enrich Dart/JS events with native integrations should prefer this property — it delegates to `SentryHub.trimmedInstalledIntegrationNames` and matches what `SentrySdkInfo` serializes.

### `SentrySDK.internal.debug` — `SentryInternalDebugApi`

| Method                                 | Replaced                                            |
| -------------------------------------- | --------------------------------------------------- |
| `images: [DebugMeta]`                  | `PrivateSentrySDKOnly.getDebugImages`               |
| `images(forAddresses:) -> [DebugMeta]` | `SentryBinaryImageCache.imageByAddress:` (see note) |

> **Note on `images`:** Flutter previously called `PrivateSentrySDKOnly.getDebugImages()` to retrieve debug meta images for symbolication. This method was not declared in the `PrivateSentrySDKOnly.h` header (it was available as a Swift-only API) and needed a proper home.
>
> **Note on `images(forAddresses:)`:** Godot previously bypassed the public API and accessed `SentryBinaryImageCache.imageByAddress(_:)` directly to look up debug images by raw `UInt64` addresses. The existing `SentryDebugImageProvider.getDebugImagesForImageAddressesFromCache(imageAddresses:)` only accepted hex `String` addresses, forcing C++/ObjC++ callers to do unnecessary string conversion. `images(forAddresses:)` accepts `[UInt64]` directly, delegates to the binary image cache, and returns `[DebugMeta]` — eliminating the need to import internal types.

### `SentrySDK.internal.breadcrumbs` — `SentryInternalBreadcrumbApi`

| Method                             | Replaced                                         |
| ---------------------------------- | ------------------------------------------------ |
| `fromDictionary(_:) -> Breadcrumb` | `PrivateSentrySDKOnly.breadcrumbWithDictionary:` |

### `SentrySDK.internal.user` — `SentryInternalUserApi`

| Method                       | Replaced                                   |
| ---------------------------- | ------------------------------------------ |
| `fromDictionary(_:) -> User` | `PrivateSentrySDKOnly.userWithDictionary:` |

## Implementation Conventions

**Swift types** (`Sources/Swift/HybridSDK/`):

- All types are `public final class` — no `NSObject`, no `@objc`, no `@_spi`.
- Dependencies are injected via provider protocols (e.g., `HubProvider`, `DebugImageProvider`) backed by `SentryDependencyContainer`, making sub-objects testable in isolation.
- `SentrySDK.internal` is a lazy `var` on `SentrySDK` protected by `NSRecursiveLock`, reset on SDK close via `resetInternalApi()`.

**ObjC wrappers** (`Sources/SentryObjC/Public/` headers + `Sources/SentryObjCCompat/` wrappers):

- Follow the two-target architecture from [SENTRY-OBJC.md](SENTRY-OBJC.md): pure ObjC header in `SentryObjC`, Swift `@objc` wrapper in `SentryObjCCompat`.
- Each wrapper holds a reference to the corresponding Swift type and delegates all calls.
- `SentryObjCSDK.internal` is a `static let` on the ObjC SDK class.
- UIKit-dependent sub-objects are guarded by `SENTRY_OBJC_REPLAY_SUPPORTED` in headers and `canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))` in Swift.
- The swizzle wrapper introduces `SentryObjCSwizzleMode` (`NS_ENUM`) mapping to `SentryInternalSwizzleApi.Mode`.

## Deprecation Strategy

Both `PrivateSentrySDKOnly` (Swift) and `SentryObjCPrivateSDKOnly` (ObjC wrapper) received deprecation annotations — class-level and per-method — pointing to the new API path. Both retain their own implementations (they do not delegate to the new Swift types). All three paths call the same SDK internals independently. Removal is planned for the next major version.

## Type Inventory

| Swift type                       | ObjC header                            | ObjC wrapper                               | Platform   |
| -------------------------------- | -------------------------------------- | ------------------------------------------ | ---------- |
| `SentryInternalApi`              | `SentryObjCInternalApi.h`              | `SentryObjCInternalApi.swift`              | all        |
| `SentryInternalReplayApi`        | `SentryObjCInternalReplayApi.h`        | `SentryObjCInternalReplayApi.swift`        | iOS, tvOS  |
| `SentryInternalProfilingApi`     | `SentryObjCInternalProfilingApi.h`     | `SentryObjCInternalProfilingApi.swift`     | iOS, macOS |
| `SentryInternalAppStartApi`      | `SentryObjCInternalAppStartApi.h`      | `SentryObjCInternalAppStartApi.swift`      | all        |
| `SentryInternalPerformanceApi`   | `SentryObjCInternalPerformanceApi.h`   | `SentryObjCInternalPerformanceApi.swift`   | iOS, tvOS  |
| `SentryInternalScreenshotApi`    | `SentryObjCInternalScreenshotApi.h`    | `SentryObjCInternalScreenshotApi.swift`    | iOS, tvOS  |
| `SentryInternalViewHierarchyApi` | `SentryObjCInternalViewHierarchyApi.h` | `SentryObjCInternalViewHierarchyApi.swift` | iOS, tvOS  |
| `SentryInternalEnvelopeApi`      | `SentryObjCInternalEnvelopeApi.h`      | `SentryObjCInternalEnvelopeApi.swift`      | all        |
| `SentryInternalScreenApi`        | `SentryObjCInternalScreenApi.h`        | `SentryObjCInternalScreenApi.swift`        | iOS, tvOS  |
| `SentryInternalSwizzleApi`       | `SentryObjCInternalSwizzleApi.h`       | `SentryObjCInternalSwizzleApi.swift`       | all        |
| `SentryInternalSdkApi`           | `SentryObjCInternalSdkApi.h`           | `SentryObjCInternalSdkApi.swift`           | all        |
| `SentryInternalDebugApi`         | `SentryObjCInternalDebugApi.h`         | `SentryObjCInternalDebugApi.swift`         | all        |
| `SentryInternalBreadcrumbApi`    | `SentryObjCInternalBreadcrumbApi.h`    | `SentryObjCInternalBreadcrumbApi.swift`    | all        |
| `SentryInternalUserApi`          | `SentryObjCInternalUserApi.h`          | `SentryObjCInternalUserApi.swift`          | all        |

**Total:** 14 Swift types + 14 ObjC headers + 14 ObjC wrappers = 42 files.

Swift types live in `Sources/Swift/HybridSDK/`, the entry point extension in `Sources/Swift/Helper/SentrySDK+Internal.swift`, ObjC headers in `Sources/SentryObjC/Public/`, and ObjC wrappers in `Sources/SentryObjCCompat/`.

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
SentrySDK.internal.sdk.setName("sentry.cocoa.react-native", version: "6.0.0")
SentrySDK.internal.appStart.hybridSDKMode = true
let frames = SentrySDK.internal.performance.currentScreenFrames
let success = SentrySDK.internal.replay.capture()
let integrations = SentrySDK.internal.sdk.trimmedInstalledIntegrationNames
```

### Flutter (hybrid SDK — native integrations on events)

```swift
// Before (v8) — Options.integrations removed in v9
import Sentry
let nativeIntegrations = PrivateSentrySDKOnly.options.integrations ?? []
// appended to event.sdk["integrations"]

// After
import Sentry
let nativeIntegrations = SentrySDK.internal.sdk.trimmedInstalledIntegrationNames
// same payload shape as event.sdk["integrations"]
```

### ObjC (hybrid SDK via SentryObjC wrapper)

```objc
// Before
#import <Sentry/PrivateSentrySDKOnly.h>
#import <Sentry/SentryOptionsInternal.h>  // Unity only
#import <Sentry/Sentry-Swift.h>           // Unity only (workaround for SentryId)
[PrivateSentrySDKOnly setSdkName:@"sentry.cocoa.react-native" andVersionString:@"6.0.0"];
PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = YES;
SentryScreenFrames *frames = PrivateSentrySDKOnly.currentScreenFrames;
[PrivateSentrySDKOnly captureReplay];
// Unity workaround for SentryId living in Swift header:
Class SentryIdClass = NSClassFromString(@"SentryId");
id traceId = [[SentryIdClass alloc] initWithUUIDString:traceString];

// After — single import, no internal headers
#import <SentryObjC/SentryObjC.h>
[[[SentryObjCSDK internal] sdk] setName:@"sentry.cocoa.react-native" version:@"6.0.0"];
[SentryObjCSDK internal].appStart.hybridSDKMode = YES;
SentryObjCScreenFrames *frames = [SentryObjCSDK internal].performance.currentScreenFrames;
BOOL success = [[[SentryObjCSDK internal] replay] capture];
NSArray<NSString *> *integrations =
    [[[SentryObjCSDK internal] sdk] trimmedInstalledIntegrationNames];
// Typed ID parameters — no NSClassFromString, no Sentry-Swift.h
SentryObjCId *traceId = [[SentryObjCId alloc] initWithUUIDString:traceString];
SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithValue:spanString];
[[SentryObjCSDK internal] setTrace:traceId spanId:spanId];
```

## Testing

- One ObjC integration test file per sub-object in `Tests/SentryObjCTests/` verifies the ObjC wrapper compiles and delegates correctly.
- Swift unit tests in `Tests/SentryTests/HybridSDK/` for each `SentryInternal*Api` type, covering the same scenarios as the existing `PrivateSentrySDKOnlyTests.swift`.
- `PrivateSentrySDKOnly` deprecation warnings compile cleanly (no errors, only warnings).
