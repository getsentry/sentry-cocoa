# Sources

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

## Objective-C

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

### Rules

- SDK runs on arbitrary queues — assume any public method can be called from any thread
- Use `@synchronized(self)` for ObjC mutable state (scope, hub, client)
- Prefer `SentryDispatchQueueWrapper` over raw `dispatch_queue_t` — it's mockable for tests
- Never do synchronous work on the main thread in production paths
- `SentryHub` dispatches transaction capture to its `dispatchQueue` for background processing

## SentryCrash (C/C++)

Located in `Sources/SentryCrash/`.

### Signal Safety

Code inside crash/signal handlers **must** be async-signal-safe:

- **No heap allocations** (`malloc`, `calloc`, `new`) — use stack buffers or pre-allocated memory
- **No locks** (`pthread_mutex`, `@synchronized`) — can deadlock if the crash occurred while holding a lock
- **No ObjC messaging** — runtime may be in an inconsistent state
- **Allowed**: `write()`, `vsnprintf`, `strerror_r`, C11 atomics, `SENTRY_ASYNC_SAFE_LOG_*` macros
- `pthread_self()` is technically not async-signal-safe but accepted as a known trade-off

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
