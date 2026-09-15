# Sources

> Scope: `Sources/**`. Also follow [root instructions](../AGENTS.md).

## Objective-C

- Prefer Swift for new code when target boundaries allow it
- Use `[[Class alloc] init]`, not `[Class new]`
- Wrap headers with `NS_ASSUME_NONNULL_BEGIN` and `NS_ASSUME_NONNULL_END`
- Mark nullable parameters and properties explicitly

## Swift

- Prefer protocol-oriented design when it improves testability or composition
- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Default to `internal` and expose only intentional SDK API as `public`
- Prefer `private` over `fileprivate`
- Mark classes `final` unless designed for subclassing

### Error Handling and Closures

- Never let the SDK crash the host app
- Wrap public entry points in `do/catch` or equivalent
- Prefer `Result<T, Error>` or optional returns over throwing for internal APIs
- Log production errors through `SentryLog` instead of assertions
- Always use explicit capture lists when capturing `self`
- Prefer `[weak self]` with `guard let self` for closures stored by the SDK

### Dependencies and Shared Access

- Prefer `SentryDependencyContainer` providers for SDK-owned dependencies
- Use `getLazyVar` or `getOptionalLazyVar` for lazily-created defaults
- Override dependencies through `SentryDependencyContainer.sharedInstance()` in tests
- Do not add static shared service singletons
- Put lifecycle-owned shared services in [`SentryDependencyContainer`](Swift/SentryDependencyContainer.swift)
- When process-lifetime hooks require global access, use a narrow proxy with synchronized weak lifecycle targets, following [`SentryNetworkTrackerProxy`](Swift/Integrations/Performance/Network/SentryNetworkTrackerProxy.swift)

### Comments

- Comment non-obvious rationale, workarounds, and gotchas, not visible behavior
- Add headerdocs for public API

## Public API

- Do not remove or rename public symbols without deprecating them with migration guidance
- Design new public API Swift-first
- Do not add `@objc`, `NSObject` inheritance, `NS_SWIFT_NAME`, or Objective-C wrappers unless an existing contract or identified consumer requires Objective-C support
- Use `@_spi(Private)` for unstable API consumed by hybrid SDKs
- Keep `@_spi(Private)` out of public headers
- Use `SENTRY_NO_INIT` for types that must not be publicly instantiated
- Follow [`develop-docs/SENTRY-OBJC.md`](../develop-docs/SENTRY-OBJC.md) for wrappers and API placement

## Conditional Compilation

- Use compile-time gates for code that cannot compile or link on a target, not for ordinary runtime behavior
- In Swift, use `os(...)`, `targetEnvironment(...)`, and `canImport(...)` for platform and module capabilities
- Gate UI code by both supported platforms and `!SENTRY_NO_UI_FRAMEWORK`
- In Objective-C and C/C++, prefer capability macros from [`SentryDefines.h`](Sentry/Public/SentryDefines.h) and [`SentryProfilingConditionals.h`](Sentry/Public/SentryProfilingConditionals.h), including `SENTRY_HAS_UIKIT`, `SENTRY_TARGET_REPLAY_SUPPORTED`, and `SENTRY_TARGET_PROFILING_SUPPORTED`
- Keep Swift, Objective-C, and `SentryObjC` declaration and implementation gates aligned
- Preserve older Xcode compatibility with `#if swift(>=...)`, compiler feature probes from [`SentryCompiler.h`](Sentry/include/SentryCompiler.h), and `canImport` or `__has_include` checks
- Use `#available` or `@available` for runtime OS availability only after the code can compile with the oldest supported Xcode
- When newer SDK symbols are absent from older Xcode headers, combine runtime availability with a compile-time gate or dynamic lookup instead of referencing the symbol directly

### Conditional Service Protocol Stripping

- Follow [`SentryNetworkTracker.swift`](Swift/Networking/SentryNetworkTracker.swift) when a service needs protocol-based mocking without retaining the abstraction in release builds
- Under `#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG`, define the service protocol, conform the concrete service, and narrow its dependency protocols for mock injection
- Under `#else`, typealias the service protocol name to the concrete generic implementation and its dependency protocol name to `SentryDependencyContainer`
- This strips the protocol abstraction from release builds while preserving the same dependency-facing names in every configuration
- Keep consumers typed against those shared names so test, debug, and release builds use the same call sites

## Thread Safety

- Assume public methods can be called from arbitrary queues
- Use `SentryMutex<T>` for new Swift mutable state
- Group related protected values in a private `State` struct
- Do not use `NSLock`, `NSRecursiveLock`, or legacy `synchronized` helpers for new Swift code
- Refactor reentrant locking before adopting non-recursive `SentryMutex`
- Use `@synchronized(self)` for Objective-C mutable state in scope, hub, and client code
- Prefer `SentryDispatchQueueWrapper` over raw queues for testability
- Never do synchronous work on the main thread in production paths

## SentryCrash

- Check upstream [KSCrash](https://github.com/kstenerud/KSCrash) when investigating relevant bugs
- Signal handlers must remain async-signal-safe
- Do not allocate heap memory, acquire locks, or send Objective-C messages in signal handlers
- Accepted signal-handler operations include `write()`, `vsnprintf`, `strerror_r`, C11 atomics, and `SENTRY_ASYNC_SAFE_LOG_*` macros
- Bounds-check fixed buffers, validate indices, and use `snprintf` instead of `sprintf`
- Treat `pthread_self()` as an explicit accepted exception to strict signal safety
