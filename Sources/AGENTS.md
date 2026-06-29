# Sources

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

## Objective-C

Use Objective-C sparingly; prefer Swift when possible.

### No `+new`

Use `[[Class alloc] init]`, not `[Class new]`:

```objc
// Correct
NSMutableArray *items = [[NSMutableArray alloc] init];
SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] init];

// Wrong
NSMutableArray *items = [NSMutableArray new];
SentryBreadcrumb *crumb = [SentryBreadcrumb new];
```

### Nullability

- Wrap header files with `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`
- Mark nullable parameters/properties explicitly with `nullable`

## Swift

Prefer protocol-oriented design where it improves testability and composition. See [Protocol-Oriented Programming in Swift (WWDC15)](https://developer.apple.com/videos/play/wwdc2015/408/) and [PR #7017](https://github.com/getsentry/sentry-cocoa/pull/7017).

**Pattern** — Define multiple protocols with default implementations via extensions. Implementing types adopt several protocols and inherit defaults for free. Protocol constraints on generics reduce required init/method signatures:

```swift
protocol ItemProtocol { var id: String { get } }
protocol StorageProtocol<Item> { associatedtype Item; func append(_ item: Item) }
protocol Enricher {
    func enrich<Item: ItemProtocol>(_ item: inout Item)
}
extension Enricher {
    func enrich<Item: ItemProtocol>(_ item: inout Item) { /* default implementation modifying item */ }
}

// Scope adopts Enricher and gets enrich() for free
extension Scope: Enricher {}

// Generic Buffer: protocols constrain Storage and Item, reducing init surface
final class Buffer<Storage: StorageProtocol, Item: ItemProtocol> {
    init(storage: Storage) { /* only needs what protocols require */ }
}
```

### Naming

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use `camelCase` for properties, methods, local variables
- Use `PascalCase` for types and protocols
- Module-level constants: `camelCase` (e.g., `sentryAutoTransactionMaxDuration`)

### Access Control

- Default to `internal` — only mark `public` what is part of the SDK's public API
- Use `private` over `fileprivate` unless sibling types in the same file need access
- `@_spi(Private)` for SPI consumed by hybrid SDKs (React Native, Flutter, .NET, Unity)

### Classes

- Mark classes `final` unless they are explicitly designed for subclassing
- Applies to both `internal` and `public` classes

### Error Handling

- Never let the SDK crash the host app — wrap all public entry points in `do/catch` or equivalent
- Prefer `Result<T, Error>` or optional returns over throwing for internal APIs
- Log errors via `SentryLog` rather than asserting in production paths

### Closures

- Always use explicit capture lists when capturing `self` to prevent retain cycles
- Prefer `[weak self]` with `guard let self` for closures stored by the SDK

### Dependency Injection

- Prefer `SentryDependencyContainer` providers for SDK-owned dependencies
- In `SentryDependencyContainer`, use `getLazyVar` / `getOptionalLazyVar` for lazily-created defaults
- Tests should override dependencies through `SentryDependencyContainer.sharedInstance()` when possible
- Do not use `PrivateSentrySDKOnly` as a test injection path when a dependency-container provider fits

## Public API Surface

- **Backward compatibility** — do not remove or rename public symbols; deprecate first
- **`@objc`** — all public API must be accessible from ObjC; use `@objc(name)` or `NS_SWIFT_NAME` for idiomatic naming in both languages
- **`@_spi(Private)`** — internal API for hybrid SDKs; must not appear in public headers
- **`PrivateSentrySDKOnly`** — ObjC SPI class; document instability in headerdocs
- **`SENTRY_NO_INIT`** — use on types that should not be publicly instantiated
- **Deprecation** — add `@available(*, deprecated, message:)` with migration guidance

## Thread Safety

### Swift: Prefer `SentryMutex`

Use `SentryMutex<T>` (in `Sources/Swift/Concurrency/SentryMutex.swift`) to protect mutable state in Swift. It wraps a value with an `os_unfair_lock`, matching the API of `Synchronization.Mutex` (iOS 18+). When the SDK's minimum deployment target reaches iOS 18+, it can be replaced with a typealias to the standard library `Mutex`.

```swift
// Single value — name the mutex after the value it protects
private let isRunning = SentryMutex<Bool>(false)

isRunning.withLock { $0 = true }
guard isRunning.withLock({ $0 }) else { return }

// Multiple related properties — group in a private State struct
private struct State {
    var count = 0
    var items: [Item] = []
}
private let state = SentryMutex(State())

state.withLock { $0.items.append(item); $0.count += 1 }
```

**Do not** use `NSLock`, `NSRecursiveLock`, or the `Locks.swift` `synchronized` extensions for new Swift code. `SentryMutex` is non-recursive — if existing code genuinely re-enters the lock, refactor the call graph first.

### Other Primitives

| Primitive          | Where                                                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------------- |
| `@synchronized`    | `SentryScope`, `SentryHub`, `SentryClient`, `SentrySDKInternal`, `SentryHttpTransport`, `SentryFileManager` |
| `NSRecursiveLock`  | Legacy Swift code (prefer `SentryMutex` for new code)                                                       |
| `pthread_mutex`    | `SentryCrashBinaryImageCache`, `SentryCrashReportStore`, `SentrySwizzle`                                    |
| `dispatch_queue_t` | `SentryDispatchQueueWrapper` (`io.sentry.http-transport`, serial, low QoS)                                  |
| `dispatch_group`   | `SentryHttpTransport` (flush coordination)                                                                  |
| C11 atomics        | SentryCrash monitors (signal-safe context)                                                                  |

### Rules

- SDK runs on arbitrary queues — assume any public method can be called from any thread
- Use `@synchronized(self)` for ObjC mutable state (scope, hub, client)
- Prefer `SentryDispatchQueueWrapper` over raw `dispatch_queue_t` — it's mockable for tests
- Never do synchronous work on the main thread in production paths
- `SentryHub` dispatches transaction capture to its `dispatchQueue` for background processing

## SentryCrash (C/C++)

Located in `Sources/SentryCrash/`. Fork of [KSCrash](https://github.com/kstenerud/KSCrash) — when fixing bugs or investigating, check upstream KSCrash for relevant fixes.

### Signal Safety

Code inside crash/signal handlers **must** be async-signal-safe:

- **No heap allocations** (`malloc`, `calloc`, `new`) — use stack buffers or pre-allocated memory
- **No locks** (`pthread_mutex`, `@synchronized`) — can deadlock if the crash occurred while holding a lock
- **No ObjC messaging** — runtime may be in an inconsistent state
- **Allowed**: `write()`, `vsnprintf`, `strerror_r`, C11 atomics, `SENTRY_ASYNC_SAFE_LOG_*` macros
- `pthread_self()` is technically not async-signal-safe but accepted as a known trade-off
- See [signal-safety(7)](https://man7.org/linux/man-pages/man7/signal-safety.7.html) and [develop docs](https://develop.sentry.dev/sdk/platform-specifics/native-sdks/signal-handlers/#general-risks) for context

### Buffer Safety

- Always bounds-check when writing to fixed-size buffers
- Use `snprintf` (never `sprintf`)
- Validate all indices before array access

### Key Components

| Component                             | Purpose                                  |
| ------------------------------------- | ---------------------------------------- |
| `SentryCrashMonitor_Signal.c`         | POSIX signal handler                     |
| `SentryCrashMonitor_MachException.c`  | Mach exception handler                   |
| `SentryCrashMonitor_NSException.m`    | ObjC uncaught exception handler          |
| `SentryCrashMonitor_CPPException.cpp` | C++ uncaught exception handler           |
| `SentryCrashReport.c`                 | Crash report generation                  |
| `SentryCrashReportStore.c`            | Report persistence                       |
| `SentryCrashJSONCodec.c`              | JSON encoding (async-signal-safe subset) |
| `SentryScopeSyncC`                    | Scope data synced for crash-time access  |
