# Architecture

**Analysis Date:** 2026-03-19

## Pattern Overview

**Overall:** Hub-Client-Transport layered architecture with integration-based plugin system.

**Key Characteristics:**

- Centralized SDK entry point (`SentrySDK`) delegating to internal `SentrySDKInternal` and `SentryHub`
- Event processing pipeline: Scope → Client → Transport → Envelope
- Hybrid ObjC/Swift codebase: ObjC core with Swift wrapper layer and feature integrations
- Protocol-oriented integration system for pluggable features (Crash, Performance, SessionReplay, etc.)
- Async-signal-safe C/C++ crash reporter (SentryCrash, fork of KSCrash)

## Layers

**Public API Layer:**

- Purpose: Stable Swift/ObjC interface for SDK consumers
- Location: `Sources/Swift/Helper/SentrySDK.swift`, `Sources/Sentry/Public/*.h`
- Contains: Static methods for initialization, event capture, transaction management, breadcrumbs
- Depends on: `SentrySDKInternal`, `SentryHub`, integrations
- Used by: Host applications, sample apps, hybrid SDKs (React Native, Flutter, .NET, Unity)

**Hub Layer:**

- Purpose: Central coordinator managing client, scope, sessions, integrations
- Location: `Sources/Swift/SentryHub.swift`, `Sources/Sentry/SentryHub.m` (ObjC)
- Contains: Hub initialization, client ownership, scope management, integration registry, session lifecycle
- Depends on: Client, Scope, Crash wrapper, Dispatch queue wrapper
- Used by: SDK public API, event capture/transaction flow, integration system

**Client Layer:**

- Purpose: Event processing, scope application, callback invocation
- Location: `Sources/Sentry/SentryClient.m` (ObjC primary), `Sources/Swift/SentryClient.swift`
- Contains: Event building, `beforeSend`/`beforeSendTransaction` callbacks, scope enrichment, transport fanout
- Depends on: Transport adapter, event context enrichers, processors, sampling decisions
- Used by: Hub (capture path), transaction recording, session events

**Event Enrichment Pipeline:**

- Purpose: Add contextual data to events before transmission
- Location: `Sources/Sentry/SentryScope.m`, `Sources/Swift/Persistence/SentryScopePersistentStore.swift`
- Contains: Tags, breadcrumbs, user, context, attachments, trace context
- Depends on: Scope, persistent storage (for scope preservation across sessions)
- Used by: Client (applyToEvent), transactions, session lifecycle

**Transport Layer:**

- Purpose: Envelope building, rate limiting, HTTP transmission, disk persistence
- Location: `Sources/Sentry/SentryTransportAdapter.m`, `Sources/Sentry/SentryHttpTransport.m`, `Sources/Swift/Networking/`
- Contains: Envelope serialization, rate limit enforcement, retry logic, file manager integration
- Depends on: File manager, rate limiters, reachability detector, network request builder
- Used by: Client, crash reporter, transport adapter

**Persistence Layer:**

- Purpose: On-disk storage for envelopes, scope state, session data
- Location: `Sources/Sentry/SentryFileManager.m`, `Sources/Swift/Persistence/`
- Contains: Envelope queue, scope snapshots (user, tags, extras, context)
- Depends on: Filesystem, serialization
- Used by: Transport (retry queue), Hub (session persistence)

**Integration System:**

- Purpose: Pluggable feature modules with optional initialization
- Location: `Sources/Swift/Integrations/`
- Contains: Breadcrumb capture, Performance tracking, SessionReplay, Crash handling, Hang detection, UserFeedback, etc.
- Depends on: Hub, integration protocols, options feature flags
- Used by: Hub (installed on SDK start), SDK features

**Crash Reporter (SentryCrash):**

- Purpose: Native crash capture and symbolication
- Location: `Sources/SentryCrash/`
- Contains: Signal/Mach exception handlers (C/C++), report generation, JSON encoding, thread inspection
- Depends on: SentryCppHelper, system frameworks (Mach API, Signal handlers)
- Used by: Hub (integration), SentrySDK (initialization)

**SwiftUI Support:**

- Purpose: SwiftUI-specific tracing and context preservation
- Location: `Sources/SentrySwiftUI/`, `Sources/Swift/SentrySwiftUI/`
- Contains: `TracedView` wrapper, environment value carriers
- Depends on: Core SDK, span/transaction APIs
- Used by: SwiftUI applications

## Data Flow

**Event Capture Flow:**

1. App calls `SentrySDK.capture(event:)` or `SentrySDK.captureError(_:)`
2. `SentrySDK` delegates to `SentrySDKInternal.capture(event:)`
3. `SentrySDKInternal` retrieves current `SentryHub`
4. `Hub.captureEvent()` calls `Client.prepareEvent(event, scope:)`
5. `Client.prepareEvent()`:
   - Applies global scope via `Scope.applyToEvent()`
   - Invokes `beforeSend` callback
   - Serializes to envelope
   - Calls `TransportAdapter.sendEvent()`
6. `TransportAdapter` fans out to configured transports (HTTP, Spotlight, etc.)
7. `SentryHttpTransport` checks rate limits, queues to disk if offline, uploads via HTTP

**Transaction Flow:**

1. App calls `SentrySDK.startTransaction(name:operation:)`
2. `SentrySDK` delegates to `SentrySDKInternal.startTransaction()`
3. `Hub.startTransaction()` creates `SentryTracer` (sampling-aware)
4. `SentryTracer` inherits current span context via `SentryScope.span`
5. App calls `transaction.finish()` on scope
6. `Hub` dispatches to background queue (io.sentry.http-transport)
7. Finished transaction converted to `SentryTransactionEvent`
8. Follows event capture flow (Client → Transport)

**Session Lifecycle Flow:**

1. `Hub.startSession()` called on first event or explicit via `SentrySDK.startSession()`
2. `Hub` creates `SentrySession`, stores in scope
3. On error: `Hub` increments session error count
4. On app backgrounding (iOS/tvOS): session state changes (paused)
5. On app foregrounding: session resumed or new session started
6. On crash: scope synced to C layer (`SentryScopeSyncC`), accessible to signal handlers
7. `Hub.endSession()` sends session update envelope via transport

**State Management:**

- **Global Scope** — shared across all events/transactions in current session, synchronized access via `@synchronized`
- **Hub-level Scope** — owns current span/transaction context, mutable only via `configureScope` callback
- **Persistent Scope** — user, tags, extras, context saved to disk across app launches via `SentryScopePersistentStore`
- **Crash-time Scope** — minimal scope data synced to C layer for availability in signal handlers

## Key Abstractions

**Event (SentryEvent):**

- Purpose: Represents a single error/message to send to Sentry
- Examples: `Sources/Sentry/Public/SentryEvent.h`, crash events, breadcrumbs, user feedback
- Pattern: Serializable protocol conformance, ObjC/Swift bridge classes with shared interface

**Transaction (SentryTransaction, SentryTracer):**

- Purpose: Distributed tracing spans with parent-child relationships
- Examples: `Sources/Swift/Transaction/`, performance monitoring, custom spans
- Pattern: Tracer manages span tree, sampling decisions, automatic instrumentation integrations hook into tracer

**Scope (SentryScope):**

- Purpose: Request-scoped context (user, tags, breadcrumbs, attachments)
- Examples: `Sources/Sentry/SentryScope.m`, `Sources/Swift/State/`
- Pattern: Thread-safe mutable state with atomic block updates via `configureScope()`

**Transport (SentryTransport):**

- Purpose: Abstract transport interface for sending envelopes
- Examples: `Sources/Sentry/SentryHttpTransport.m`, `SentrySpotlightTransport` (debug), test transports
- Pattern: Protocol-based, injectable, composable (adapter fans to multiple transports)

**Envelope (SentryEnvelope):**

- Purpose: Wire format combining multiple event items (error, transaction, session, metrics)
- Examples: `Sources/Sentry/SentryEnvelopeItemHeader.m`, serialization in `SentrySerialization.m`
- Pattern: Builder pattern for multi-item construction, protocol-driven serialization

**Integration (SwiftIntegration, SentryIntegration):**

- Purpose: Pluggable feature modules with optional initialization
- Examples: `Sources/Swift/Integrations/Performance/`, SessionReplay, Crash handler
- Pattern: Generic init taking `Options` + dependencies, `uninstall()` for cleanup, installed by Hub on `start()`

## Entry Points

**SentrySDK (Static Public API):**

- Location: `Sources/Swift/Helper/SentrySDK.swift`
- Triggers: App initialization, capture calls, transaction start
- Responsibilities: Route calls to SDKInternal, provide metrics/logger/replay APIs, session management

**SentrySDKInternal (Routing):**

- Location: `Sources/Sentry/SentrySDKInternal.m` (ObjC primary)
- Triggers: SentrySDK delegate calls
- Responsibilities: Initialize Hub/Client on first call, dispatch to currentHub, thread safety via locks

**SentryHub (Coordination):**

- Location: `Sources/Swift/SentryHub.swift`, `Sources/Sentry/SentryHub.m`
- Triggers: Event capture, transaction start, scope mutation
- Responsibilities: Route to Client, manage integrations, handle sessions

**SentryClient (Event Processing):**

- Location: `Sources/Sentry/SentryClient.m`
- Triggers: Event ready for send (from Hub)
- Responsibilities: Build envelopes, apply scope, invoke callbacks, send to transport

**Integrations (Feature Setup):**

- Location: `Sources/Swift/Integrations/*`
- Triggers: Hub initialization with options flags
- Responsibilities: Hook into iOS/UIKit lifecycles, capture contextual data, wire to transport

## Error Handling

**Strategy:** Defense-in-depth — no crashes, graceful degradation.

**Patterns:**

- **Public API** — wrapped in `do/catch` or try/catch equivalents, errors logged not propagated
- **Event Capture** — silently dropped if event fails processing, error logged via `SentryLog`
- **Transport** — network failures trigger disk queue, rate limit errors cause backoff
- **Crash Handler** — async-signal-safe subset only (no heap allocation, no locks)
- **Integrations** — init returns `nil` if unavailable (e.g., Performance integration disabled), uninstall always succeeds

## Cross-Cutting Concerns

**Logging:** `SentrySDKLog` (Swift) and `SentryLogC` (ObjC), leveled (debug/info/warning/error/fatal), routed to SentryLogger integration

**Validation:** Event properties validated at serialization time, scope data sanitized via `SentryNSDictionarySanitize`, type safety via ObjC/Swift types

**Authentication:** DSN parsed to project ID and API key, embedded in every outgoing envelope via `SentryNSURLRequestBuilder`

**Serialization:** `SentrySerialization.m` (ObjC) handles JSON/msgpack encoding, event/transaction/session/metrics all conform to `SentrySerializable` protocol

**Thread Safety:**

- Hub, Client, Scope guarded by `@synchronized(self)` (ObjC)
- Transport uses `SentryDispatchQueueWrapper` (serial queue, low QoS)
- Crash handlers use C11 atomics (signal-safe)
- Integration install happens atomically via lock-protected registry

---

_Architecture analysis: 2026-03-19_
