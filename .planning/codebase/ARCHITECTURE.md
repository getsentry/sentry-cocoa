# Architecture

**Analysis Date:** 2026-02-13

## Pattern Overview

**Overall:** Hub-and-Scope pattern with Client-Transport-Transport pipeline

**Key Characteristics:**

- Thread-safe hub singleton manages the active client and scope
- Layered event processing: Event → Client → Transport → Network/Disk
- Integration-based feature system with ordered installation
- Dual Objective-C core + Swift API surface for compatibility
- Dependency injection via `SentryDependencyContainer` for testability

## Layers

**API Layer (Swift):**

- Purpose: Public API for SDK initialization, capturing events, and managing scope
- Location: `Sources/Swift/Helper/SentrySDK.swift`, `Sources/Swift/Core/`
- Contains: Public methods for `start()`, `capture()`, metrics, logging, transaction management
- Depends on: SDKInternal (Objective-C), Integrations, Options
- Used by: Application code, integrations

**Hub/Client Layer (Objective-C):**

- Purpose: Central coordination of event capture, session tracking, and integrations
- Location: `Sources/Sentry/SentryHub.m`, `Sources/Sentry/SentryClient.m`, `Sources/Sentry/SentrySDKInternal.m`
- Contains: Hub singleton management, Client initialization, scope binding, integration installation
- Depends on: Transports, Crash reporting, Options, Scope
- Used by: Swift API layer, event capture methods

**Transport Layer (Objective-C + Swift):**

- Purpose: Serialization, HTTP transmission, and offline queueing of events
- Location: `Sources/Sentry/SentryHttpTransport.m`, `Sources/Swift/Networking/`
- Contains: HTTP transport implementation, rate limiting, retry logic, envelope serialization
- Depends on: NSURLSession, file persistence, rate limits
- Used by: Client for sending events/sessions/transactions

**Persistence Layer (Swift + Objective-C):**

- Purpose: Offline storage of events and scope state
- Location: `Sources/Sentry/SentryFileManagerHelper.m`, `Sources/Swift/Persistence/`
- Contains: File-based envelope storage, scope serialization, crash report caching
- Depends on: File system, JSON serialization
- Used by: Transport, Client, Crash integration

**Integration Layer (Swift + Objective-C):**

- Purpose: Feature plugins for auto-instrumentation (crash reporting, performance, breadcrumbs, etc.)
- Location: `Sources/Swift/Integrations/`, `Sources/Swift/Core/Integrations/`
- Contains: Auto-tracking integrations (ANR, frames, network, UI events, crash, session replay)
- Depends on: Frameworks being instrumented (UIKit, CoreData, NSURLSession)
- Used by: Hub during initialization

**Crash Reporting Layer (C/C++ + Objective-C):**

- Purpose: Low-level crash capture and machine context gathering
- Location: `Sources/Sentry/SentryCrash*.{h,m,c}`, `Sources/Sentry/Profiling/`
- Contains: Mach exception handling, stack unwinding, symbol lookup, profiling data
- Depends on: POSIX APIs, mach kernel APIs
- Used by: Crash integration, event conversion

**Context Enrichment (Objective-C):**

- Purpose: Gather and attach device/app context to events
- Location: `Sources/Sentry/SentryDevice.m`, `Sources/Sentry/SentryEvent+Private.h`
- Contains: Device info, OS version, thread state, memory usage
- Depends on: UIKit/AppKit (optional), system APIs
- Used by: Client when processing events

## Data Flow

**Event Capture Flow:**

1. Application calls `SentrySDK.capture(event:)` or integrated instrumentation triggers event
2. Swift API layer (`SentrySDK.swift`) delegates to `SentrySDKInternal` (Objective-C)
3. `SentrySDKInternal` retrieves current `Hub` and calls `captureEvent:withScope:`
4. `SentryHub` enriches event with scope data and applies processors
5. `SentryHub` passes to `SentryClient` which triggers transport chain
6. `SentryClient` applies event context enrichers (device, app, trace context)
7. Transport serializes event to msgpack envelope format
8. Transport attempts HTTP POST to Sentry backend
9. On network failure, Transport queues to persistent storage for retry

**State Management:**

- Global Hub singleton (`SentrySDKInternal.currentHub`) is thread-safe via locks
- Each thread has scope context via `SentryScope` - accessed via Hub API only
- Scope changes are NOT automatically persisted; explicit persistence via `SentryScopePersistentStore`
- Integration state managed through `Hub.installedIntegrations` array
- Session state (started/ended) tracked in Hub with sessionDelegate callback

**Trace Propagation:**

1. Transaction created via `Hub.startTransaction(name:operation:)` creates `SentryTracer`
2. Tracer maintains current span via `SentryHubInternal.currentSpan`
3. Spans bound to scope for HTTP context propagation
4. W3C trace context (baggage, sentry-trace header) extracted/injected by Network integration
5. Child spans created from current span in Hub

## Key Abstractions

**SentryOptions:**

- Purpose: Configuration container with 100+ settings
- Examples: `dsn`, `enabled`, `tracesSampleRate`, `environment`, `integrations` list
- Pattern: Mutable options builder during init, read-only in Client

**SentryScope:**

- Purpose: Thread-local context for events (user, tags, breadcrumbs, attachments)
- Examples: `setUser:`, `setTag:value:`, `addBreadcrumb:`
- Pattern: Scopes managed via Hub API, not direct access; scope-local context bound to Hub

**SentryTransport (Protocol):**

- Purpose: Abstraction for event delivery mechanism
- Implementations: `SentryHttpTransport` (live), `SentrySpotlightTransport` (local debug)
- Pattern: Factory creates transports from options; multiple transports can be active

**SentryIntegrationProtocol + SwiftIntegration:**

- Purpose: Plugin interface for auto-instrumentation features
- Examples: `SentryNetworkTrackingIntegration`, `SentryANRTrackerIntegration`, `SentryCrashIntegration`
- Pattern: Each integration installed sequentially during SDK start, uninstalled on close

**SentrySpanProtocol + SentryTracer:**

- Purpose: Transaction and span abstraction for performance tracking
- Examples: APM transactions, database operations, network requests
- Pattern: Tracer acts as root span; child spans created on demand

## Entry Points

**SDK Initialization:**

- Location: `Sources/Swift/Helper/SentrySDK.swift` - `start(configureOptions:)`
- Triggers: Creates `SentryOptions`, initializes `SentryClient`, installs integrations, starts sessions
- Responsibilities: One-time setup, validation, dependency container initialization

**Event Capture:**

- Locations:
  - `SentrySDK.capture(event:)` - Swift public API
  - `SentryHub.captureEvent:withScope:` - Hub internal
  - `SentryClient.captureEvent:withScope:` - Client implementation
- Triggers: Application code or auto-instrumentation
- Responsibilities: Enrich event, apply processors, invoke transport

**Integration Installation:**

- Location: `Sources/Swift/Core/Integrations/Integrations.swift` - `SentrySwiftIntegrationInstaller.install(with:)`
- Triggers: During SDK start
- Responsibilities: Instantiate each integration in order, register with Hub

**Crash Reporting:**

- Location: `Sources/Sentry/SentryCrash.h` - C API for mach exception registration
- Triggers: Automatically installed by `SentryCrashIntegration`
- Responsibilities: Monitor for crashes, write to disk synchronously, report on next launch

**Trace Context Flow:**

- Locations: Network integration hooks URLSession, transforms requests with trace headers
- Triggers: Every HTTP request through URLSession
- Responsibilities: Extract/inject trace context (W3C format), create network spans

## Error Handling

**Strategy:** Multi-level error handling with graceful degradation

**Patterns:**

- Silent failures: Most integration failures don't block SDK startup
- Validation: Options validated on init, invalid values logged and skipped
- Fallbacks: No transport → queueing disabled; no file manager → cache disabled
- Assertion logging: Internal errors logged via `SentryLogC` (async-safe C logging)
- User handling: Capture errors always succeed (return empty ID on failure)
- Critical errors: Only crash reporting failures can be fatal (must not crash handler)

## Cross-Cutting Concerns

**Logging:**

- Two systems: Sync `SentryLogC.m` (async-safe for crash context), async `SentryLogger` (general)
- Via `SENTRY_LOG_DEBUG`, `SENTRY_LOG_ERROR` macros in C, `SentrySDKLog` in Swift
- In crash handler, only async-safe C logging safe

**Validation:**

- Options validation: Type checking, range validation, conflicting setting checks
- Event validation: Ensure required fields (event_id, timestamp), sanitize large values
- Transport validation: Rate limit checks, HTTP status code interpretation

**Authentication:**

- DSN parsing extracts auth credentials (`publicKey`, `secretKey`)
- Credentials embedded in request auth header and envelope envelope
- Client IP address optionally whitelisted via options

**Thread Safety:**

- Hub access: Protected by `currentHubLock` NSObject for singleton
- Scope mutations: Protected by scope's internal lock on write
- Session tracking: Protected by `_sessionLock` in Hub
- Integration tracking: Protected by `_integrationsLock` in Hub
- File operations: Serialized through dispatch queue wrapper

**Memory Management:**

- Weak references used for delegates, observers to prevent cycles
- Atomic properties for frequently accessed state (client, options)
- Scope and Hub not retained by integrations (callback-based instead)

---

_Architecture analysis: 2026-02-13_
