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

## ObjC/Swift Interop in `_SentryPrivate`

The `_SentryPrivate` module exposes private ObjC headers to Swift via `SentryPrivate.h`. Dependency direction: `SentrySwift` → `_SentryPrivate` (not the reverse). This means **`_SentryPrivate` headers cannot resolve Swift-defined types**.

### The SPM Trap

When an ObjC header in `_SentryPrivate` references a Swift class (e.g., `SentryEnvelope *`), methods using that type are **silently dropped** in SPM builds. The Xcode project build works because all code shares one module, but SPM separates targets.

**Symptoms:** `has no member 'foo'` or `missing argument label` errors only in SPM / CI, never locally in Xcode.

### Fix: `SENTRY_SWIFT_MIGRATION_ID` + `NS_SWIFT_NAME`

Use `SENTRY_SWIFT_MIGRATION_ID(TypeName)` (expands to `id`) to erase the Swift type, making the method visible in SPM. Add `NS_SWIFT_NAME(...)` to preserve the auto-translated Swift name (auto-translation differs between `TypeName *` and `id`):

```objc
// Wrong — invisible to Swift in SPM when SentryEnvelope is a Swift class
- (void)storeEnvelope:(SentryEnvelope *)envelope;

// Correct — visible everywhere
- (void)storeEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope NS_SWIFT_NAME(store(_:));
```

See `SentryHub+SwiftPrivate.h` for the established pattern with `captureReplayEvent:` and session listener methods.

### Checklist for New Methods in Private ObjC Headers

- [ ] Does any parameter or return type name a Swift class? Check `Sources/Swift/` for the type definition
- [ ] If yes, use `SENTRY_SWIFT_MIGRATION_ID(TypeName)` for the parameter type
- [ ] Add explicit `NS_SWIFT_NAME(...)` to control the Swift-visible name
- [ ] Verify with `swift build` (SPM), not just `make build-ios` (Xcode)

## Public API Surface

- **Backward compatibility** — do not remove or rename public symbols; deprecate first
- **`@objc`** — all public API must be accessible from ObjC; use `@objc(name)` or `NS_SWIFT_NAME` for idiomatic naming in both languages
- **`@_spi(Private)`** — internal API for hybrid SDKs; must not appear in public headers
- **`PrivateSentrySDKOnly`** — ObjC SPI class; document instability in headerdocs
- **`SENTRY_NO_INIT`** — use on types that should not be publicly instantiated
- **Deprecation** — add `@available(*, deprecated, message:)` with migration guidance

## Thread Safety

### Primitives in Use

| Primitive          | Where                                                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------------- |
| `@synchronized`    | `SentryScope`, `SentryHub`, `SentryClient`, `SentrySDKInternal`, `SentryHttpTransport`, `SentryFileManager` |
| `NSLock`           | `SentrySessionReplay`                                                                                       |
| `NSRecursiveLock`  | `SentrySDK.startOptionLock`                                                                                 |
| `pthread_mutex`    | `SentryCrashBinaryImageCache`, `SentryCrashReportStore`, `SentrySwizzle`                                    |
| `dispatch_queue_t` | `SentryDispatchQueueWrapper` (`io.sentry.http-transport`, serial, low QoS)                                  |
| `dispatch_group`   | `SentryHttpTransport` (flush coordination)                                                                  |
| C11 atomics        | SentryCrash monitors (signal-safe context)                                                                  |

For Swift, use the `synchronized` extensions in `Locks.swift` (`NSLock`, `NSRecursiveLock`) rather than raw lock calls.

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
