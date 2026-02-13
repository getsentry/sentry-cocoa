# Phase 1: Facade Design & Implementation - Research

**Researched:** 2026-02-13
**Domain:** Swift/Objective-C interoperability, facade pattern, dependency injection in mixed-language iOS SDK
**Confidence:** HIGH

## Summary

This phase implements a facade (bridge) class to decouple SentryCrash from SentryDependencyContainer by providing a concrete SDK-side class that exposes five specific services SentryCrash needs. The research confirms this is a well-established pattern in the Sentry Cocoa SDK codebase, with strong precedents in existing wrapper classes and helper bridges.

The facade pattern is appropriate here because SentryCrash needs a simplified interface to SDK services without coupling to the full dependency container singleton. Swift's `@objc` attribute and NSObject inheritance provide seamless Objective-C interoperability with minimal overhead.

**Primary recommendation:** Create a concrete `SentryCrashBridge` class in Sources/Swift that inherits from NSObject, marks all five service properties as `@objc`, and is instantiated by SDK initialization before SentryCrash installation. Follow existing patterns from SentryDependencyContainerSwiftHelper for bridging Swift services to Objective-C.

## Standard Stack

### Core

| Library     | Version | Purpose                                | Why Standard                                       |
| ----------- | ------- | -------------------------------------- | -------------------------------------------------- |
| Swift 5.x+  | Current | Primary facade implementation language | Native iOS SDK development, excellent ObjC interop |
| Foundation  | Current | NSObject base class, @objc bridging    | Required for ObjC interoperability                 |
| Objective-C | Current | SentryCrash implementation             | Legacy crash reporting code, cannot be rewritten   |

### Supporting

| Component         | Location                 | Purpose                     | When to Use                             |
| ----------------- | ------------------------ | --------------------------- | --------------------------------------- |
| `@objc` attribute | Swift classes/properties | Expose Swift to Objective-C | All facade interface elements           |
| `@objcMembers`    | Class-level annotation   | Expose all members to ObjC  | When entire class needs ObjC visibility |
| `@_spi(Private)`  | Access control           | Internal SDK API exposure   | Cross-module SDK internal APIs          |

### Alternatives Considered

| Instead of         | Could Use             | Tradeoff                                                                             |
| ------------------ | --------------------- | ------------------------------------------------------------------------------------ |
| Concrete class     | Protocol-based facade | User preference for concrete class; simpler, more direct                             |
| Facade on SDK side | Facade in SentryCrash | Would create wrong dependency direction; SentryCrash should not own SDK dependencies |
| Property passing   | Method-based API      | Properties are simpler for service access patterns in this codebase                  |

**Installation:**

```swift
// No external dependencies needed - all Foundation/Swift standard library
```

## Architecture Patterns

### Recommended Project Structure

```
Sources/Swift/
├── Integrations/SentryCrash/
│   ├── SentryCrashIntegration.swift    # Initializes facade before installation
│   └── SentryCrashBridge.swift         # NEW: Facade class
├── SentryCrash/
│   └── SentryCrashWrapper.swift         # Will consume facade instead of container
└── SentryDependencyContainer.swift      # Provides services to facade
```

### Pattern 1: Concrete Facade with @objc Properties

**What:** A concrete class that bridges Swift SDK services to Objective-C SentryCrash code
**When to use:** When bridging services from higher-level (SDK) to lower-level (crash reporting) subsystems

**Example:**

```swift
// Source: Existing pattern in SentryDependencyContainerSwiftHelper.m/h
@objc @_spi(Private) public final class SentryCrashBridge: NSObject {

    // Service 1: Notification center for app lifecycle events
    @objc public let notificationCenterWrapper: SentryNSNotificationCenterWrapper

    // Service 2: Date provider for timestamps
    @objc public let dateProvider: SentryCurrentDateProvider

    // Service 3: Crash reporter for system info and crash state
    @objc public let crashReporter: SentryCrashSwift

    // Service 4: Exception handler reference
    @objc public var uncaughtExceptionHandler: (@convention(c) (NSException) -> Void)? {
        return crashReporter.uncaughtExceptionHandler
    }

    // Service 5: Active screen dimensions (iOS/tvOS only)
    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    @objc public func activeScreenSize() -> CGSize {
        return SentryDependencyContainerSwiftHelper.activeScreenSize()
    }
    #endif

    @objc public init(
        notificationCenterWrapper: SentryNSNotificationCenterWrapper,
        dateProvider: SentryCurrentDateProvider,
        crashReporter: SentryCrashSwift
    ) {
        self.notificationCenterWrapper = notificationCenterWrapper
        self.dateProvider = dateProvider
        self.crashReporter = crashReporter
        super.init()
    }
}
```

### Pattern 2: Lazy Property Bridging for Complex Types

**What:** Computed properties that bridge to underlying services without storing duplicate references
**When to use:** For services that are properties of other services (uncaughtExceptionHandler is a property of crashReporter)

**Example:**

```swift
// Instead of storing uncaughtExceptionHandler separately, bridge to crashReporter's property
@objc public var uncaughtExceptionHandler: (@convention(c) (NSException) -> Void)? {
    return crashReporter.uncaughtExceptionHandler
}
```

### Pattern 3: Facade Initialization in Integration

**What:** SDK integration creates and configures facade before installing crash reporting
**When to use:** Standard initialization pattern in this codebase

**Example:**

```swift
// In SentryCrashIntegration.init(with:dependencies:)
let bridge = SentryCrashBridge(
    notificationCenterWrapper: dependencies.notificationCenterWrapper,
    dateProvider: dependencies.dateProvider,
    crashReporter: dependencies.crashReporter
)

// Pass to SentryCrash before installation
SentryCrash.configureBridge(bridge)
```

### Anti-Patterns to Avoid

- **Circular dependencies:** Facade should only reference SDK services, never import SentryCrash
- **Singleton facade:** Pass facade instance explicitly, don't create another singleton
- **Leaking implementation details:** Facade exposes services, not how they're implemented
- **Late initialization:** Configure facade before SentryCrash installation, not after

## Don't Hand-Roll

| Problem                       | Don't Build                          | Use Instead                       | Why                                                               |
| ----------------------------- | ------------------------------------ | --------------------------------- | ----------------------------------------------------------------- |
| Swift/ObjC bridging           | Custom C wrapper functions           | `@objc` attribute + NSObject      | Apple's standard interop mechanism, well-tested, minimal overhead |
| Type conversion               | Manual conversions for each property | Native Swift-ObjC bridging        | Foundation handles most conversions automatically                 |
| Protocol conformance checking | Runtime checks in ObjC               | Swift protocol constraints        | Compile-time safety, better performance                           |
| Memory management             | Manual retain/release                | ARC with appropriate weak/unowned | ARC handles cross-language boundaries correctly                   |

**Key insight:** Swift-to-ObjC bridging is a solved problem with excellent tooling. Don't create custom bridging layers when `@objc` suffices.

## Common Pitfalls

### Pitfall 1: Using @objc on Types That Can't Bridge

**What goes wrong:** Swift types like generics, structs without @objc support, and tuple types cannot be exposed to Objective-C, causing compilation errors
**Why it happens:** Attempting to expose Swift-only types that have no Objective-C representation
**How to avoid:** Use @objc-compatible types only: classes inheriting from NSObject, primitives, Foundation types
**Warning signs:** Compiler error "Type X cannot be represented in Objective-C"

### Pitfall 2: Forgetting NSObject Inheritance

**What goes wrong:** Swift classes marked `@objc` but not inheriting from NSObject cause runtime crashes when accessed from Objective-C
**Why it happens:** @objc requires NSObject inheritance for full interoperability
**How to avoid:** Always make facade classes inherit from NSObject: `class SentryCrashBridge: NSObject`
**Warning signs:** Compilation succeeds but crashes at runtime when ObjC code accesses Swift class

### Pitfall 3: Creating Circular Dependencies

**What goes wrong:** Facade imports SentryCrash code, SentryCrash imports facade, causing import cycles
**Why it happens:** Bidirectional dependencies between layers
**How to avoid:** Facade only imports SDK services; SentryCrash receives facade as parameter
**Warning signs:** "Circular import" compilation errors

### Pitfall 4: Singleton Proliferation

**What goes wrong:** Creating `SentryCrashBridge.sharedInstance()` creates another singleton, defeating the purpose of dependency injection
**Why it happens:** Following singleton pattern because SentryDependencyContainer is a singleton
**How to avoid:** Pass facade instance explicitly as a parameter, store in SentryCrash properties
**Warning signs:** Need for global static access to facade

### Pitfall 5: Late Initialization Timing

**What goes wrong:** Creating facade after SentryCrash has already started causes SentryCrash to access nil services
**Why it happens:** Wrong initialization order
**How to avoid:** Create and configure facade in SentryCrashIntegration.init before calling installation
**Warning signs:** Crashes accessing nil facade properties, especially in notification handlers

### Pitfall 6: @objc Performance Overhead Misunderstanding

**What goes wrong:** Avoiding @objc due to perceived performance overhead when overhead is negligible for this use case
**Why it happens:** Misunderstanding the scope of @objc overhead
**How to avoid:** Understand that @objc overhead is minimal for property access and method calls (statically typed selectors); only dynamic dispatch with string-based selectors has 20% overhead
**Warning signs:** Over-engineering custom bridging solutions

### Pitfall 7: Exposing Wrong Access Level

**What goes wrong:** Making facade public when it should be internal to SDK
**Why it happens:** Unclear visibility requirements
**How to avoid:** Use `@_spi(Private)` to expose to SDK-internal Objective-C code without making public API
**Warning signs:** Facade appearing in generated Swift interface header for external consumers

## Code Examples

Verified patterns from official sources and existing codebase:

### Swift Class Accessible from Objective-C

```swift
// Source: Existing pattern in SentryCrashWrapper.swift, SentryNSNotificationCenterWrapper.swift
@objc @_spi(Private) public final class SentryCrashBridge: NSObject {
    // Properties and methods here
}
```

### Bridging Protocol Types

```swift
// Source: SentryNSNotificationCenterWrapper.swift protocol bridging pattern
@objc @_spi(Private) public protocol SentryNSNotificationCenterWrapper {
    func addObserver(_ observer: Any, selector aSelector: Selector, name aName: NSNotification.Name?, object anObject: Any?)
}

// In facade:
@objc public let notificationCenterWrapper: SentryNSNotificationCenterWrapper
```

### Conditional Compilation for Platform-Specific Services

```swift
// Source: SentryDependencyContainerSwiftHelper.h pattern
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
@objc public func activeScreenSize() -> CGSize {
    return SentryDependencyContainerSwiftHelper.activeScreenSize()
}
#endif
```

### Facade Initialization in Integration

```swift
// Source: Derived from SentryCrashIntegration.swift initialization patterns
init?(with options: Options, dependencies: Dependencies) {
    // ... validation ...

    // Create facade before installing SentryCrash
    let bridge = SentryCrashBridge(
        notificationCenterWrapper: dependencies.notificationCenterWrapper,
        dateProvider: dependencies.dateProvider,
        crashReporter: dependencies.crashReporter
    )

    super.init()

    // Configure SentryCrash with facade before installation
    // (exact mechanism TBD in implementation phase)

    // Then install SentryCrash
    startCrashHandler(/* ... */)
}
```

### Accessing Facade from Objective-C

```objc
// Source: Pattern from SentryCrash.m accessing SentryDependencyContainer
// Replace:
id<SentryNSNotificationCenterWrapper> notificationCenter
    = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;

// With:
id<SentryNSNotificationCenterWrapper> notificationCenter
    = self.bridge.notificationCenterWrapper;
```

## State of the Art

| Old Approach                           | Current Approach                         | When Changed              | Impact                                                        |
| -------------------------------------- | ---------------------------------------- | ------------------------- | ------------------------------------------------------------- |
| Direct container access in SentryCrash | Facade pattern with dependency injection | This refactor (2026)      | Decouples SentryCrash from SDK, enables independent evolution |
| Singleton access throughout            | Parameter-based dependency passing       | Ongoing SDK modernization | Improved testability, clearer dependencies                    |
| Mixed Swift/ObjC with tight coupling   | Clear layer boundaries with bridges      | This refactor             | Better architecture, easier maintenance                       |

**Deprecated/outdated:**

- Direct `SentryDependencyContainer.sharedInstance()` access from SentryCrash code: Will be replaced by facade pattern

## Open Questions

1. **Facade storage in SentryCrash**
   - What we know: SentryCrash is Objective-C, needs to store bridge reference
   - What's unclear: Best property name, whether to store in SentryCrash.m or SentryCrashInstallation.m
   - Recommendation: Store in SentryCrash.m as instance property, since both Installation and direct usage need access

2. **Thread safety requirements**
   - What we know: SentryDependencyContainer uses locks, properties are thread-safe
   - What's unclear: Whether facade properties need explicit thread safety or inherit from services
   - Recommendation: No additional synchronization needed; facade is immutable after initialization, services handle their own thread safety

3. **Testing strategy for facade**
   - What we know: Existing wrapper classes have test mocks in SentryTestUtils
   - What's unclear: Whether to mock facade or continue mocking underlying services
   - Recommendation: Continue mocking underlying services; facade is simple pass-through, not worth separate mocking

## Sources

### Primary (HIGH confidence)

- Existing codebase patterns:
  - `/Sources/Swift/Helper/SentryNSNotificationCenterWrapper.swift` - Protocol bridging pattern
  - `/Sources/Swift/Helper/SentryDispatchQueueWrapper.swift` - Wrapper class pattern with @objc
  - `/Sources/Sentry/SentryDependencyContainerSwiftHelper.h/m` - Helper bridge pattern for accessing Swift from ObjC
  - `/Sources/Swift/SentryCrash/SentryCrashWrapper.swift` - Existing wrapper with @objc and lazy properties
  - `/Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift` - Integration initialization pattern
- Apple Documentation:
  - [Importing Objective-C into Swift](https://developer.apple.com/documentation/swift/importing-objective-c-into-swift) - Official interop guide

### Secondary (MEDIUM confidence)

- [iOS Handbook - Swift-Objective C interoperability and best practices](https://infinum.com/handbook/ios/miscellaneous/swift-objective-c-interoperability-and-best-practices) - @objc attribute usage
- [Bridging Objective-C and Swift Classes](https://medium.com/@subhangdxt/bridging-objective-c-and-swift-classes-5cb4139d9c80) - Bridge class patterns
- [Swift and Objective-C Interoperability With @objc](https://holyswift.app/swift-and-objective-c-interoperability-with-objc-and-objcmembers/) - @objc vs @objcMembers
- [The Facade Design Pattern In Swift](https://serialcoder.dev/text-tutorials/software-engineering/design-patterns/the-facade-design-pattern-in-swift/) - Facade pattern overview
- [Singleton vs Dependency Injection in Swift](https://getstream.io/blog/singleton-dependency-injection-in-swift/) - Singleton pitfalls, DI benefits
- [Performance Optimization Best Practices for Combining Objective-C and Swift](https://moldstud.com/articles/p-performance-optimization-best-practices-for-combining-objective-c-and-swift) - @objc performance considerations

### Tertiary (LOW confidence)

- [Design Patterns in Swift #3: Facade and Adapter](https://www.appcoda.com/design-pattern-structural/) - General facade concepts (not iOS SDK specific)

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - Based on existing codebase patterns and Apple documentation
- Architecture: HIGH - Clear precedent in SentryDependencyContainerSwiftHelper and wrapper classes
- Pitfalls: HIGH - Derived from official docs, codebase experience, and verified web sources

**Research date:** 2026-02-13
**Valid until:** 60 days (stable patterns, minimal API churn in Swift/ObjC interop)
