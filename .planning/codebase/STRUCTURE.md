# Codebase Structure

**Analysis Date:** 2026-03-19

## Directory Layout

```
sentry-cocoa/
├── Sources/                 # SDK source code (ObjC/Swift)
│   ├── Sentry/              # Core ObjC layer (Hub, Client, Scope, Transport, Crash integration)
│   ├── Swift/               # Swift layer (public API, integrations, networking, persistence)
│   ├── SentryCrash/         # Native crash reporting (C/C++, KSCrash fork)
│   ├── SentryCppHelper/     # C++ helpers (backtrace, sampling, thread introspection)
│   ├── SentrySwiftUI/       # SwiftUI support (TracedView, environment values)
│   ├── SentryDistribution/  # dSYM distribution framework (separate library)
│   ├── Configuration/       # Build-time configuration
│   └── Resources/           # SDK resources (version info)
├── Tests/                   # Unit and integration tests
│   ├── SentryTests/         # Main test suite (ObjC/Swift)
│   ├── SentryProfilerTests/ # Profiler tests
│   └── Configuration/       # Test-specific configuration
├── Samples/                 # Demo applications (iOS, macOS, tvOS, watchOS, visionOS)
├── develop-docs/            # Maintainer documentation (architecture decisions, implementation guides)
├── scripts/                 # Build and utility scripts (Bash)
├── .github/                 # GitHub workflows (CI/CD, release)
├── Package.swift            # Swift Package Manager manifest
├── Sentry.xcodeproj/        # Main Xcode project
└── Sentry.xcworkspace/      # Xcode workspace (project + dependencies)
```

## Directory Purposes

**Sources/Sentry/:**

- Purpose: Objective-C core SDK implementation
- Contains: Hub, Client, Scope, Transport, Serialization, Event processors
- Key files: `SentrySDKInternal.m`, `SentryHub.m`, `SentryClient.m`, `SentryScope.m`, `SentryHttpTransport.m`, `SentryFileManager.m`
- Public API headers: `Sources/Sentry/Public/*.h`
- Private headers: `Sources/Sentry/include/*.h`

**Sources/Sentry/Profiling/:**

- Purpose: Sampled profiler implementation (C++/ObjC++)
- Contains: Profiling context manager, stack sampling, serialization to JSON/msgpack
- Key files: Sampler, ProfileBuilder, UncachedSourceMapResolver

**Sources/Swift/:**

- Purpose: Swift wrapper layer and feature integrations
- Subdirectories:
  - `Helper/` — SentrySDK public entry point, DSN parsing, SDK info
  - `Core/` — Swift extensions, integration protocols, MetricKit utilities
  - `Integrations/` — Feature plugins (Performance, SessionReplay, Crash, etc.)
  - `Networking/` — Rate limiting, request building, reachability detection
  - `Persistence/` — Scope state snapshot storage across sessions
  - `AppState/` — App lifecycle, foreground/background state tracking
  - `State/` — Swift state management (Session, Transaction, Span)
  - `Transaction/` — Transaction and Span implementations
  - `Tools/` — Utilities (logging, SDK info, environment helpers)

**Sources/SentryCrash/:**

- Purpose: Native crash reporting (C/C++, async-signal-safe)
- Subdirectories:
  - `Recording/` — Crash monitors (Signal, Mach exception, NSException, C++ exception)
  - `Reporting/` — Report generation, filtering, persistence
  - `Installations/` — Platform-specific crash handler setup
- Key files: `SentryCrashMonitor_Signal.c`, `SentryCrashReport.c`, `SentryCrashReportStore.c`

**Sources/SentryCppHelper/:**

- Purpose: C++ utilities for profiling and crash handling
- Contains: Backtrace capture, sampling profiler, thread handle wrappers
- Used by: Profiler, SentryCrash monitors

**Sources/SentrySwiftUI/:**

- Purpose: SwiftUI integration (separate from main framework)
- Contains: `TracedView` wrapper, environment value protocol
- Requires: Xcode 12.0+ (SwiftUI 2.0)

**Sources/SentryDistribution/:**

- Purpose: Separate library for dSYM distribution and symbol handling
- Contains: Mach-O parsing, dSYM network upload, caching
- Tests: `Sources/SentryDistributionTests/`

**Tests/SentryTests/:**

- Purpose: Main test suite (XCTest)
- Subdirectories match source structure:
  - `Transaction/` — Transaction, Span, Tracer tests
  - `SentryCrash/` — Crash reporter tests
  - `Integrations/` — Integration tests (Performance, SessionReplay, etc.)
  - `Networking/` — Transport, rate limit, request building tests
  - `Persistence/` — File manager, scope storage tests
  - `State/` — Session, scope state tests
  - `Extensions/` — Swift extensions tests
  - `Protocol/` — Integration protocol tests
  - `Transactions/` — Auto-instrumentation tests (CoreData, Network, etc.)
- Key patterns: Mocked dependencies (transport, file manager, HTTP client), `XCTestCase` subclasses

**Tests/SentryProfilerTests/:**

- Purpose: Sampled profiler tests
- Contains: Sampling, serialization, symbol resolution tests

**Samples/:**

- Purpose: Demo applications showing SDK integration
- Subdirectories (by platform/language):
  - iOS: `iOS-Swift/`, `iOS-SwiftUI/`, `iOS-ObjectiveC/`, `iOS-Cocoapods-Swift6/`, etc.
  - macOS: `macOS-Swift/`, `macOS-SwiftUI-SPM/`, `macOS-CLI-Xcode/`, etc.
  - tvOS: `tvOS-Swift/`, `tvOS-SwiftUI-SPM/`
  - visionOS: `visionOS-Swift/`, `visionOS-SwiftUI-SPM/`, `visionOS-SPM/`
  - watchOS: `watchOS-Swift/`
- Special samples:
  - `SPM/` — Swift Package Manager integration example
  - `XCFramework-Validation/` — Binary framework validation
  - `DistributionSample/` — dSYM distribution API demo
  - `SessionReplay-CameraTest/` — SessionReplay privacy testing
  - `SDK-Size/` — Binary size measurement
- Shared: `Shared/`, `SentrySampleShared/` (common configurations, helper views)

**develop-docs/:**

- Purpose: Maintainer documentation (not for SDK users)
- Contains: Architecture decisions, implementation guides, performance notes
- Key files: `SentryCrash-Analysis.md`, `Profiler-Implementation.md`, etc.

**scripts/:**

- Purpose: Build automation and utilities
- Contains: Shell scripts following named-parameter template
- Key scripts: Build helpers, release automation, code generation

**.github/:**

- Purpose: GitHub Actions workflows and configuration
- Contains: Workflows for CI (build, test, lint), release automation, danger checks
- Key files: `.github/workflows/build.yml`, `.github/CODEOWNERS`, `pull_request_template.md`

**Package.swift:**

- Purpose: Swift Package Manager manifest
- Defines: Multiple product targets (Sentry, Sentry-Dynamic, SentrySwiftUI, SentryDistribution)
- Binary targets: Pre-built xcframeworks for SPM consumers
- Source targets: SentrySwift (wrapper), SentryObjCInternal (full compilation)

**Sentry.xcodeproj/:**

- Purpose: Xcode project configuration
- Contains: Build phases, schemes (iOS, macOS, tvOS, watchOS, visionOS), test targets
- Schemes: Build and test per-platform (make build-ios, make test-macos, etc.)

## Key File Locations

**Entry Points:**

- `Sources/Swift/Helper/SentrySDK.swift` — Public SDK static API (start, capture, transactions, metrics)
- `Sources/Sentry/SentrySDKInternal.m` — Internal routing and Hub management
- `Sources/Swift/SentryHub.swift` — Hub public interface (Objective-C bridge to ObjC SentryHub.m)

**Core Logic:**

- `Sources/Sentry/SentryClient.m` — Event processing, envelope building, beforeSend callbacks
- `Sources/Sentry/SentryScope.m` — Context storage (user, tags, breadcrumbs, attachments)
- `Sources/Sentry/SentryHub.m` — Hub coordination, integration registry, session lifecycle

**Transport & Persistence:**

- `Sources/Sentry/SentryHttpTransport.m` — HTTP upload, rate limiting, retry queue
- `Sources/Sentry/SentryFileManager.m` — Envelope persistence (disk queue, path management)
- `Sources/Swift/Persistence/SentryScopePersistentStore.swift` — Scope snapshot storage

**Integration System:**

- `Sources/Swift/Integrations/` — All feature integrations (subdirectories by feature)
  - `Performance/SentryPerformanceTrackingIntegration.swift` — UIViewController tracing
  - `SessionReplay/` — Session recording integration
  - `SentryCrash/` — Native crash integration
  - `Breadcrumbs/` — Automatic breadcrumb capture
  - `Metrics/` — Metrics API integration

**Crash Reporting:**

- `Sources/SentryCrash/Recording/SentryCrashMonitor_Signal.c` — Signal handler
- `Sources/SentryCrash/Recording/SentryCrashMonitor_MachException.c` — Mach exception handler
- `Sources/SentryCrash/Reporting/SentryCrashReport.c` — Crash JSON generation

**Utilities:**

- `Sources/Sentry/SentrySerialization.m` — JSON/msgpack encoding (events, transactions, sessions)
- `Sources/Swift/Networking/` — Rate limits, HTTP request building, reachability
- `Sources/Swift/Tools/SentrySDKLog*.swift` — Structured logging framework

**Profiler:**

- `Sources/Sentry/Profiling/` — C++/ObjC++ sampled profiler (stacks, symbols)

**SwiftUI:**

- `Sources/SentrySwiftUI/TracedView.swift` — SwiftUI view wrapper
- `Sources/Swift/SentrySwiftUI/` — SwiftUI environment integration

## Naming Conventions

**Files:**

- ObjC implementation: `Sentry*.m` (e.g., `SentryClient.m`)
- ObjC header: `Sentry*.h` (public in `Public/`, private in `include/`)
- Swift: `Sentry*.swift` (e.g., `SentrySDK.swift`)
- Tests: `Sentry*Tests.swift`, `Sentry*Test.m`, `*Spec.swift` (rarer)
- Integration features: Named by feature (e.g., `SentryPerformanceTrackingIntegration.swift`, `SentryCrashIntegration.swift`)

**Directories:**

- Feature integrations: `Integrations/<FeatureName>/` (e.g., `Integrations/Performance/`)
- Platform-specific: No directory separation (uses `#if os(...)` preprocessor directives)
- Tests mirror sources: `Tests/SentryTests/<Category>/` matches `Sources/<Category>/`

## Where to Add New Code

**New Feature (e.g., new integration):**

- Primary code: Create `Sources/Swift/Integrations/<FeatureName>/` directory
- Conformance: Implement `SwiftIntegration` protocol (init, uninstall, static name)
- Registration: Add to integration factory or auto-discovered by Hub
- Tests: Create `Tests/SentryTests/Integrations/<FeatureName>/`

**New Component/Module (e.g., new processor type):**

- If ObjC core logic: `Sources/Sentry/Sentry<ComponentName>.m` + `SentrySDKInternal.h` header
- If Swift wrapper: `Sources/Swift/Core/`, `Sources/Swift/State/`, or appropriate subdirectory
- If integration: Follow **New Feature** path above
- Public API: Add headers to `Sources/Sentry/Public/` if needed

**Utilities/Helpers:**

- Shared helpers: `Sources/Swift/Helper/` (SentrySDK-scoped) or `Sources/Swift/Tools/` (general)
- ObjC utilities: `Sources/Sentry/` (inline or separate file depending on size)
- Test utilities: `Tests/SentryTests/TestUtils/` or inline in test file

**Networking/Transport:**

- Rate limiting, request building: `Sources/Swift/Networking/`
- Transport implementations: `Sources/Sentry/Sentry*Transport.m`

**Persistence:**

- Scope snapshots: `Sources/Swift/Persistence/SentryScopePersistentStore+<Category>.swift`
- File management: `Sources/Sentry/SentryFileManager.m`

**Tests:**

- Unit tests: Co-located with source (same relative path under `Tests/`)
- Mocking: Use `SentryTestUtils` framework (in-repo, separate from main SDK)
- Fixtures: `Tests/SentryTests/TestUtils/`, reused across test files

## Special Directories

**Sources/Sentry/Processors/:**

- Purpose: Event processors (limited — most are in integrations)
- Generated: No
- Committed: Yes

**Sources/Configuration/:**

- Purpose: Build-time configuration headers (generated by build system)
- Generated: Yes (build phases populate)
- Committed: No (generated during build)

**Sources/Resources/:**

- Purpose: SDK version strings, metadata (not user-facing assets)
- Generated: Partially (version from Package.swift)
- Committed: Yes

**Tests/Resources/:**

- Purpose: Test fixtures (JSON crash reports, call stacks, etc.)
- Generated: No (static test data)
- Committed: Yes

**Samples/SampleAssets.xcassets/:**

- Purpose: Shared image/color assets for demo apps
- Generated: No
- Committed: Yes

**.build/, BuildOutput/, .swiftpm/:**

- Purpose: Build artifacts, caches
- Generated: Yes
- Committed: No

**develop-docs/:**

- Purpose: Maintainer notes (not published to users)
- Generated: No
- Committed: Yes

---

_Structure analysis: 2026-03-19_
