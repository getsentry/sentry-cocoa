# SentrySDK.internal — Structured Hybrid SDK API

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
2. **Pure Swift with `@_spi(Private)`.** The `SentrySDK.internal` API is Swift-only. No `@objc` annotations, no `NSObject` inheritance on the internal API types. All types are marked `@_spi(Private)` to restrict visibility to consumers that explicitly opt in via `@_spi(Private) import Sentry`. Objective-C consumers use the ObjC wrapper SDK (`SentryObjCSDK.internal`).
3. **Always available.** `SentrySDK.internal` is a lazy `var` property (protected by `NSRecursiveLock`) that works before and after `SentrySDK.start()`. It is reset on SDK close via `resetInternalApi()`. Sub-object methods that require a running SDK return nil or no-op, matching current `PrivateSentrySDKOnly` behavior.
4. **Deprecate, don't remove.** `PrivateSentrySDKOnly` gets deprecation annotations but keeps its own implementation for at least one major version. It does not delegate to the new types (since they're pure Swift and it's ObjC).
5. **Single PR.** All sub-objects and deprecations ship in one PR.

## Non-Goals

- Removing `PrivateSentrySDKOnly` (future major version).
- Wrapping types already available in the public API (e.g., `SentrySDK.replay` for end users).
- Changing the internal SDK architecture. The new types call the same internal code that `PrivateSentrySDKOnly` does today.

## Eliminating Internal Header Imports

Beyond replacing `PrivateSentrySDKOnly`, this API also eliminates the need for hybrid SDKs to import other internal headers:

### `SentryOptionsInternal.h`

Unity imports this solely for `+initWithDict:didFailWithError:`, which creates `SentryOptions` from a dictionary passed across the C#→ObjC bridge. This is already mapped to `.internal.options(fromDictionary:)` / `[[… internal] optionsFromDictionary:error:]`.

### `SentrySwizzle.h`

React Native imports this for the `SentrySwizzleInstanceMethod` macro to swizzle `viewDidAppear:` on `RNSScreen` for frame tracking. The macro API is tightly coupled to the internal implementation (factory blocks, `SentrySwizzleInfo`, IMP casting).

With the new API, `SentrySDK.internal.swizzle.instanceMethod(_:in:mode:key:factory:)` / `[[[SentryObjCSDK internal] swizzle] swizzleInstanceMethod:inClass:newImpFactory:mode:key:]` wraps the same underlying `SentrySwizzle` mechanism behind a stable method call. Hybrid SDKs no longer need the header search path or macro definitions.

### `Sentry-Swift.h`

Unity imports this to access `SentryId` and `SentrySpanId` types, which are Swift classes only available to ObjC through the auto-generated bridging header. The Unity code even documents the workaround: _"This is a workaround to deal with SentryId living inside the Swift header."_ It uses `NSClassFromString()` to load these types dynamically.

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
                    SentryInternalApi (@_spi(Private), pure Swift)
                          |
                    SentryInternalReplayApi, etc. (@_spi(Private), pure Swift)
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

Methods are grouped by integration area, following the model established in PR [#8017](https://github.com/getsentry/sentry-cocoa/pull/8017).

### `SentrySDK.internal` (root — `SentryInternalApi`)

Direct methods (no natural integration group):

| Method                                       | Replaces                                                       |
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

### `SentrySDK.internal.profiling` — `SentryInternalProfilingApi`

| Method                                        | Replaces                              |
| --------------------------------------------- | ------------------------------------- |
| `start(for traceId:) -> UInt64`               | `startProfilerForTrace:`              |
| `collect(between:and:for:) -> [String: Any]?` | `collectProfileBetween:and:forTrace:` |
| `discard(for traceId:)`                       | `discardProfilerForTrace:`            |

### `SentrySDK.internal.appStart` — `SentryInternalAppStartApi`

| Method                                                            | Replaces                           | Platform guard           |
| ----------------------------------------------------------------- | ---------------------------------- | ------------------------ |
| `hybridSDKMode: Bool`                                             | `appStartMeasurementHybridSDKMode` | none                     |
| `measurementWithSpans: [String: Any]?`                            | `appStartMeasurementWithSpans`     | none                     |
| `measurement: SentryAppStartMeasurement?`                         | `appStartMeasurement`              | `SENTRY_UIKIT_AVAILABLE` |
| `onMeasurementAvailable: ((SentryAppStartMeasurement?) -> Void)?` | `onAppStartMeasurementAvailable`   | `SENTRY_UIKIT_AVAILABLE` |

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

### `SentrySDK.internal.swizzle` — `SentryInternalSwizzleApi`

Replaces direct import of `SentrySwizzle.h` and its macro-based API (`SentrySwizzleInstanceMethod`, `SentrySWReturnType`, etc.).

| Method                                           | Replaces                            |
| ------------------------------------------------ | ----------------------------------- |
| `instanceMethod(_:in:mode:key:factory:) -> Bool` | `SentrySwizzleInstanceMethod` macro |

The factory block receives a closure that returns the original `IMP`. The caller returns a new block (cast to `id`) that becomes the replacement implementation. This matches the underlying `SentrySwizzle` factory pattern but without requiring the header or macro definitions.

**Mode enum** (`SentryInternalSwizzleApi.Mode`):

| Case                           | Behavior                                                           |
| ------------------------------ | ------------------------------------------------------------------ |
| `.always`                      | Swizzle every time, even if already swizzled                       |
| `.oncePerClass`                | Swizzle only once per class (recommended default)                  |
| `.oncePerClassAndSuperclasses` | Swizzle only if neither this class nor any superclass was swizzled |

> **Why not expose a simplified "before/after hook" API?** The factory-based API preserves full flexibility (custom argument handling, conditional forwarding, return value modification) at the cost of the caller doing IMP casting. A convenience wrapper could be added later if multiple hybrid SDKs converge on a simpler pattern.

### `SentrySDK.internal.sdk` — `SentryInternalSdkApi`

| Method                        | Replaces                                            |
| ----------------------------- | --------------------------------------------------- |
| `name: String`                | `PrivateSentrySDKOnly.getSdkName` / `.setSdkName:`  |
| `versionString: String`       | `PrivateSentrySDKOnly.getSdkVersionString`          |
| `setName(_:version:)`         | `PrivateSentrySDKOnly.setSdkName:andVersionString:` |
| `addPackage(name:version:)`   | `PrivateSentrySDKOnly.addSdkPackage:version:`       |
| `extraContext: [String: Any]` | `PrivateSentrySDKOnly.getExtraContext`              |
| `installationID: String`      | `PrivateSentrySDKOnly.installationID`               |

`name` and `versionString` are read-write properties — the getter and setter replace both the get/set static methods.

### `SentrySDK.internal.debug` — `SentryInternalDebugApi`

| Method                                 | Replaces                                            |
| -------------------------------------- | --------------------------------------------------- |
| `images: [DebugMeta]`                  | `PrivateSentrySDKOnly.getDebugImages`               |
| `images(forAddresses:) -> [DebugMeta]` | `SentryBinaryImageCache.imageByAddress:` (see note) |

> **Note on `images`:** Flutter calls `PrivateSentrySDKOnly.getDebugImages()` to retrieve debug meta images for symbolication. This method is not declared in the current `PrivateSentrySDKOnly.h` header (it's available via `@_spi(Private)`) but is a real call site that needs a home.
>
> **Note on `images(forAddresses:)`:** Godot currently bypasses the public API and accesses `SentryBinaryImageCache.imageByAddress(_:)` directly to look up debug images by raw `UInt64` addresses. The existing `SentryDebugImageProvider.getDebugImagesForImageAddressesFromCache(imageAddresses:)` only accepts hex `String` addresses, forcing C++/ObjC++ callers to do unnecessary string conversion. The new `images(forAddresses:)` accepts `[UInt64]` directly, delegates to the binary image cache, and returns `[DebugMeta]` — eliminating the need to import internal types.

### `SentrySDK.internal.breadcrumbs` — `SentryInternalBreadcrumbApi`

| Method                             | Replaces                                         |
| ---------------------------------- | ------------------------------------------------ |
| `fromDictionary(_:) -> Breadcrumb` | `PrivateSentrySDKOnly.breadcrumbWithDictionary:` |

### `SentrySDK.internal.user` — `SentryInternalUserApi`

| Method                       | Replaces                                   |
| ---------------------------- | ------------------------------------------ |
| `fromDictionary(_:) -> User` | `PrivateSentrySDKOnly.userWithDictionary:` |

## Swift Implementation Pattern

Each sub-object is a plain Swift class marked `@_spi(Private)` (no `NSObject`, no `@objc`). Dependencies are injected via provider protocols conforming to `SentryDependencyContainer`, making the sub-objects testable in isolation:

```swift
// Sources/Swift/HybridSDK/SentryInternalApi.swift

@_implementationOnly import _SentryPrivate

@_spi(Private) public final class SentryInternalApi {

    private let container: SentryDependencyContainer

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    public let replay: SentryInternalReplayApi
    public let performance: SentryInternalPerformanceApi
    public let screenshot: SentryInternalScreenshotApi
    public let viewHierarchy: SentryInternalViewHierarchyApi
    public let screen: SentryInternalScreenApi
    #endif

    #if SENTRY_TARGET_PROFILING_SUPPORTED
    public let profiling = SentryInternalProfilingApi()
    #endif

    public let appStart = SentryInternalAppStartApi()
    public let envelope: SentryInternalEnvelopeApi
    public let swizzle = SentryInternalSwizzleApi()
    public let sdk: SentryInternalSdkApi
    public let debug: SentryInternalDebugApi
    public let breadcrumbs = SentryInternalBreadcrumbApi()
    public let user = SentryInternalUserApi()

    // ... direct methods (setTrace, setLogOutput, ignoreNextSignal, options) ...
}
```

```swift
// Sources/Swift/HybridSDK/SentryInternalReplayApi.swift

@_spi(Private) public final class SentryInternalReplayApi {

    private let hubProvider: any HubProvider

    internal init(provider: any HubProvider) {
        self.hubProvider = provider
    }

    @discardableResult
    public func capture() -> Bool {
        guard let integration = hubProvider.hub.installedIntegration(
            of: SentrySessionReplayIntegration.self
        ) else { return false }
        return integration.captureReplay()
    }

    public var replayId: String? {
        hubProvider.hub.scope.replayId
    }

    // ... other methods ...
}
```

```swift
// Sources/Swift/HybridSDK/SentryInternalSwizzleApi.swift

@_spi(Private) public final class SentryInternalSwizzleApi {

    public enum Mode {
        case always
        case oncePerClass
        case oncePerClassAndSuperclasses
    }

    @discardableResult
    public func instanceMethod(
        _ selector: Selector,
        in cls: AnyClass,
        mode: Mode = .oncePerClass,
        key: UnsafeRawPointer,
        factory: @escaping (_ getOriginalImplementation: @escaping () -> IMP) -> Any
    ) -> Bool {
        let swizzleMode: SentrySwizzleMode = switch mode {
        case .always: .always
        case .oncePerClass: .oncePerClass
        case .oncePerClassAndSuperclasses: .oncePerClassAndSuperclasses
        }
        return SentrySwizzle.swizzleInstanceMethod(
            selector,
            in: cls,
            newImpFactory: { swizzleInfo in
                factory {
                    unsafeBitCast(
                        swizzleInfo!.getOriginalImplementation(),
                        to: IMP.self
                    )
                }
            },
            mode: swizzleMode,
            key: key
        )
    }
}
```

The `SentrySDK` extension uses a lazy singleton protected by a lock, allowing reset on SDK close:

```swift
// Sources/Swift/Helper/SentrySDK+Internal.swift

extension SentrySDK {
    @_spi(Private) public static var `internal`: SentryInternalApi {
        // Lazy singleton protected by NSRecursiveLock.
        // resetInternalApi() tears it down on SDK close.
    }

    static func resetInternalApi() { ... }
}
```

## ObjC Wrapper Pattern

Following the two-target architecture from [SENTRY-OBJC.md](SENTRY-OBJC.md):

**Header** (`Sources/SentryObjC/Public/SentryObjCInternalApi.h`):

```objc
#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCDefines.h>

@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCOptions;
@class SentryObjCInternalReplayApi;
@class SentryObjCInternalPerformanceApi;
@class SentryObjCInternalScreenshotApi;
@class SentryObjCInternalViewHierarchyApi;
@class SentryObjCInternalScreenApi;
@class SentryObjCInternalProfilingApi;
@class SentryObjCInternalAppStartApi;
@class SentryObjCInternalEnvelopeApi;
@class SentryObjCInternalSwizzleApi;
@class SentryObjCInternalSdkApi;
@class SentryObjCInternalDebugApi;
@class SentryObjCInternalBreadcrumbApi;
@class SentryObjCInternalUserApi;

@interface SentryObjCInternalApi : NSObject

#if SENTRY_OBJC_REPLAY_SUPPORTED
@property (nonatomic, readonly) SentryObjCInternalReplayApi *replay;
@property (nonatomic, readonly) SentryObjCInternalPerformanceApi *performance;
@property (nonatomic, readonly) SentryObjCInternalScreenshotApi *screenshot;
@property (nonatomic, readonly) SentryObjCInternalViewHierarchyApi *viewHierarchy;
@property (nonatomic, readonly) SentryObjCInternalScreenApi *screen;
#endif

@property (nonatomic, readonly) SentryObjCInternalAppStartApi *appStart;
@property (nonatomic, readonly) SentryObjCInternalEnvelopeApi *envelope;
@property (nonatomic, readonly) SentryObjCInternalSwizzleApi *swizzle;
@property (nonatomic, readonly) SentryObjCInternalSdkApi *sdk;
@property (nonatomic, readonly) SentryObjCInternalDebugApi *debug;
@property (nonatomic, readonly) SentryObjCInternalBreadcrumbApi *breadcrumbs;
@property (nonatomic, readonly) SentryObjCInternalUserApi *user;

- (void)setTrace:(SentryObjCId *)traceId spanId:(SentryObjCSpanId *)spanId;
- (void)setLogOutput:(void (^)(NSString *))output;
- (void)ignoreNextSignal:(int)signum;
@property (nonatomic, readonly) SentryObjCOptions *options;
- (nullable SentryObjCOptions *)optionsFromDictionary:(NSDictionary<NSString *, id> *)dictionary
                                                error:(NSError **)error;

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
    @objc public var performance: SentryObjCInternalPerformanceApi {
        SentryObjCInternalPerformanceApi(wrapped.performance)
    }
    // ... screenshot, viewHierarchy, screen follow same pattern ...
    #endif

    @objc public var appStart: SentryObjCInternalAppStartApi { ... }
    @objc public var envelope: SentryObjCInternalEnvelopeApi { ... }
    @objc public var swizzle: SentryObjCInternalSwizzleApi { ... }
    @objc public var sdk: SentryObjCInternalSdkApi { ... }
    @objc public var debug: SentryObjCInternalDebugApi { ... }
    @objc public var breadcrumbs: SentryObjCInternalBreadcrumbApi { ... }
    @objc public var user: SentryObjCInternalUserApi { ... }

    @objc public func setTrace(_ traceId: SentryObjCId, spanId: SentryObjCSpanId) { ... }
    @objc public func setLogOutput(_ output: @escaping (String) -> Void) { ... }
    @objc public func ignoreNextSignal(_ signum: Int32) { ... }
    // ...
}
```

**SentryObjCSDK extension** (`Sources/SentryObjCCompat/SentryObjCSDK+Internal.swift`):

```swift
extension SentryObjCSDK {
    @objc public static let `internal` = SentryObjCInternalApi()
}
```

**Swizzle header** (`Sources/SentryObjC/Public/SentryObjCInternalSwizzleApi.h`):

```objc
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SentryObjCSwizzleMode) {
    SentryObjCSwizzleModeAlways = 0,
    SentryObjCSwizzleModeOncePerClass = 1,
    SentryObjCSwizzleModeOncePerClassAndSuperclasses = 2
};

/// Stable swizzling API for hybrid SDKs.
/// Replaces direct import of SentrySwizzle.h and its macro-based API.
@interface SentryObjCInternalSwizzleApi : NSObject

/// Swizzle an instance method. The factory block receives a block that
/// returns the original IMP; return a new block matching the method signature.
- (BOOL)swizzleInstanceMethod:(SEL _Nonnull)selector
                      inClass:(Class _Nonnull)cls
                newImpFactory:(id _Nonnull (^_Nonnull)(IMP _Nonnull (^_Nonnull)(void)))factoryBlock
                         mode:(SentryObjCSwizzleMode)mode
                          key:(const void *_Nonnull)key;

@end
```

Each sub-object follows the same header + wrapper pair pattern. See [SENTRY-OBJC.md](SENTRY-OBJC.md) for the full wrapper conventions.

## Deprecation Strategy

Both `PrivateSentrySDKOnly` (Swift) and `SentryObjCPrivateSDKOnly` (ObjC wrapper) receive deprecation annotations. The entire `SentryObjCPrivateSDKOnly` class is deprecated, and each method has an individual annotation pointing to the new API path:

```objc
// SentryObjCPrivateSDKOnly.h — class-level deprecation
DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal instead")
@interface SentryObjCPrivateSDKOnly : NSObject

// Per-method deprecation (e.g. for sdk name)
+ (void)setSdkName:(NSString *)name andVersionString:(NSString *)version
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.sdk.setName:version:");
```

`PrivateSentrySDKOnly` retains its own implementation (does not delegate to the new Swift types). Both paths call the same SDK internals independently. Removal happens in the next major version.

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

**Total:** 14 Swift types + 14 ObjC headers + 14 ObjC wrappers = 42 new files.

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
│       ├── SentryInternalScreenApi.swift
│       ├── SentryInternalSwizzleApi.swift
│       ├── SentryInternalSdkApi.swift
│       ├── SentryInternalDebugApi.swift
│       ├── SentryInternalBreadcrumbApi.swift
│       └── SentryInternalUserApi.swift
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
│   ├── SentryObjCInternalScreenApi.h
│   ├── SentryObjCInternalSwizzleApi.h
│   ├── SentryObjCInternalSdkApi.h
│   ├── SentryObjCInternalDebugApi.h
│   ├── SentryObjCInternalBreadcrumbApi.h
│   └── SentryObjCInternalUserApi.h
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
│   ├── SentryObjCInternalSwizzleApi.swift
│   ├── SentryObjCInternalSdkApi.swift
│   ├── SentryObjCInternalDebugApi.swift
│   ├── SentryObjCInternalBreadcrumbApi.swift
│   ├── SentryObjCInternalUserApi.swift
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
SentrySDK.internal.sdk.setName("sentry.cocoa.react-native", version: "6.0.0")
SentrySDK.internal.appStart.hybridSDKMode = true
let frames = SentrySDK.internal.performance.currentScreenFrames
let success = SentrySDK.internal.replay.capture()
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
// Typed ID parameters — no NSClassFromString, no Sentry-Swift.h
SentryObjCId *traceId = [[SentryObjCId alloc] initWithUUIDString:traceString];
SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithValue:spanString];
[[SentryObjCSDK internal] setTrace:traceId spanId:spanId];
```

### ObjC — Swizzle migration (React Native)

```objc
// Before — requires internal header search path
#if __has_include(<Sentry/SentrySwizzle.h>)
#    import <Sentry/SentrySwizzle.h>
#else
#    import "SentrySwizzle.h"
#endif

+ (void)swizzleViewDidAppear
{
    Class rnsscreenclass = NSClassFromString(@"RNSScreen");
    if (rnsscreenclass == nil) { return; }

    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(rnsscreenclass, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [[[RNSentryDependencyContainer sharedInstance] framesTrackerListener] startListening];
            SentrySWCallOriginal(animated);
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

// After — single import, no internal headers, no macros
#import <SentryObjC/SentryObjC.h>

+ (void)swizzleViewDidAppear
{
    Class rnsscreenclass = NSClassFromString(@"RNSScreen");
    if (rnsscreenclass == nil) { return; }

    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    [[[SentryObjCSDK internal] swizzle]
        swizzleInstanceMethod:selector
        inClass:rnsscreenclass
        newImpFactory:^id(IMP (^getOriginal)(void)) {
            return ^void(__unsafe_unretained id self, BOOL animated) {
                [[[RNSentryDependencyContainer sharedInstance] framesTrackerListener] startListening];
                ((void (*)(id, SEL, BOOL))getOriginal())(self, selector, animated);
            };
        }
        mode:SentryObjCSwizzleModeOncePerClass
        key:(void *)selector];
}
```

## Public API Surface Impact

- `sdk_api.json` gains ~75 new public symbols (14 types + their methods/properties).
- `sdk_api_objc.json` gains ~75 new symbols (14 ObjC types + methods + `SentryObjCSwizzleMode` enum).
- `PrivateSentrySDKOnly` / `SentryObjCPrivateSDKOnly` gain `deprecated` annotations (no removal, no ABI break).
- `make generate-public-api` must be run and committed.

## Testing

- One ObjC integration test file per sub-object in `Tests/SentryObjCTests/` verifying the ObjC wrapper compiles and delegates correctly.
- Swift unit tests in `Tests/SentryTests/HybridSDK/` for each `SentryInternal*Api` type, covering the same scenarios as existing `PrivateSentrySDKOnlyTests.swift`.
- Verify `PrivateSentrySDKOnly` deprecation warnings compile cleanly (no errors, only warnings).

## Open Questions

1. **`SentryObjCSDK.internal` naming in ObjC.** `internal` is not a reserved word in ObjC, so no conflict. But should we verify no collision with Apple's runtime selectors?
2. **Thread safety.** `PrivateSentrySDKOnly` methods are individually thread-safe via internal SDK locks. The new types delegate to the same internals, inheriting the same guarantees. Should we add `@Sendable` annotations to callback parameters?
3. ~~**`SentryInternalApi` as singleton vs. value.**~~ **Resolved:** implemented as a lazy `var` protected by `NSRecursiveLock`, with `resetInternalApi()` called on SDK close. This allows sub-objects to be recreated with fresh dependencies when the SDK restarts.
