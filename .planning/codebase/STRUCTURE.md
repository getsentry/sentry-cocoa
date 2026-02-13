# Codebase Structure

**Analysis Date:** 2026-02-13

## Directory Layout

```
sentry-cocoa/
├── Sources/
│   ├── Sentry/                          # Core Objective-C SDK implementation
│   │   ├── include/                     # Private headers for internal use
│   │   ├── Public/                      # Public headers exported in SDK
│   │   ├── Processors/                  # Event processor implementations
│   │   ├── Profiling/                   # CPU/memory profiling (C++/Obj-C)
│   │   ├── *Client.m                    # Event capture and processing
│   │   ├── *Hub.m                       # Hub singleton and scope management
│   │   ├── *SDKInternal.m               # SDK lifecycle and integration management
│   │   ├── *Transport.m                 # HTTP transport and envelope handling
│   │   ├── SentryCrash*.{m,h,c}         # Crash reporting system
│   │   └── Sentry*.m                    # Feature implementations (120+ files)
│   │
│   └── Swift/                           # Swift API layer and integrations
│       ├── Helper/                      # Utility extensions and helpers
│       │   ├── InfoPlist/               # Info.plist parsing
│       │   └── SentrySDK.swift          # Main public Swift API
│       │
│       ├── Core/                        # Core abstractions
│       │   ├── Extensions/              # Foundation/UIKit extensions
│       │   ├── Helper/                  # Shared helper utilities
│       │   ├── Integrations/            # Core integrations (ANR, frames, performance)
│       │   ├── MetricKit/               # Apple MetricKit integration
│       │   ├── Protocol/                # Protocol definitions
│       │   ├── Tools/                   # Build tools (formatters, sanitizers)
│       │   └── *Config.swift            # Configuration classes
│       │
│       ├── Integrations/                # Feature integrations
│       │   ├── AppStartTracking/        # App startup performance measurement
│       │   ├── Breadcrumbs/             # UI/system event tracking
│       │   ├── Metrics/                 # Metrics collection
│       │   ├── Performance/             # Transaction and span creation
│       │   ├── Screenshot/              # Screenshot attachment on error
│       │   ├── SentryCrash/             # Crash reporting setup
│       │   ├── Session/                 # Session tracking and health
│       │   ├── SessionReplay/           # Screen replay recording
│       │   ├── UIEventTracking/         # UIView/UIViewController tracking
│       │   ├── UserFeedback/            # User feedback collection
│       │   ├── ViewHierarchy/           # View hierarchy serialization
│       │   ├── WatchdogTerminations/    # Background termination tracking
│       │   └── Integrations.swift       # Integration installer and protocol
│       │
│       ├── Networking/                  # HTTP transport layer
│       │   ├── RateLimits.swift         # Rate limiting logic
│       │   ├── SentryReachability.swift # Network connectivity detection
│       │   └── *Parser.swift            # HTTP header parsing
│       │
│       ├── Persistence/                 # Local storage
│       │   └── SentryScopePersistentStore*.swift   # Scope persistence
│       │
│       ├── State/                       # App and SDK state
│       │   ├── SentryPropagationContext.swift
│       │   └── SentryScopeObserver.swift
│       │
│       ├── Tools/                       # Processing and utilities
│       │   ├── TelemetryBuffer/         # Telemetry data collection
│       │   ├── TelemetryProcessor/      # Telemetry processing
│       │   ├── TelemetryScopeApplier/   # Telemetry scope tracking
│       │   └── *Helper.swift            # Utility functions
│       │
│       ├── AppState/                    # Application state tracking
│       │
│       ├── SentryCrash/                 # Crash report conversion
│       │
│       ├── SentrySwiftUI/               # SwiftUI-specific helpers
│       │
│       ├── Transaction/                 # Transaction management
│       │
│       └── Protocol/Codable/            # Serialization protocols
│
├── Tests/
│   ├── SentryTests/                     # Main unit test suite
│   │   ├── Helper/                      # Test mocks and utilities
│   │   ├── Integrations/                # Integration tests
│   │   ├── Networking/                  # Transport/HTTP tests
│   │   ├── Protocol/                    # Protocol/serialization tests
│   │   ├── SentryCrash/                 # Crash report converter tests
│   │   ├── Categories/                  # Category method tests
│   │   ├── Persistence/                 # Persistence/serialization tests
│   │   ├── Resources/                   # Test fixtures and data
│   │   ├── Recording/                   # HTTP recording playback
│   │   └── *Tests.swift                 # Individual test files
│   │
│   ├── SentryProfilerTests/             # Profiling-specific tests
│   │
│   ├── Perf/                            # Performance benchmark tests
│   │
│   ├── DuplicatedSDKTest/               # Multi-SDK compatibility tests
│   │
│   └── Configuration/                   # Test configuration
│
├── TestSamples/                         # Sample apps for manual testing
│   ├── SwiftUITestSample/
│   └── SwiftUICrashTest/
│
├── develop-docs/                        # Development documentation
│   ├── SENTRYCRASH.md                  # Crash reporter documentation
│   └── *.md                             # Architecture/design docs
│
├── .github/                             # GitHub workflows and templates
├── fastlane/                            # Build automation scripts
├── build/                               # Build artifacts
├── Sentry.xcodeproj/                    # Main Xcode project
├── Sentry.podspec                       # CocoaPods specification
├── Package.swift                        # Swift Package Manager manifest
├── AGENTS.md                            # Development guidelines
└── Makefile                             # Build commands (format, test, etc)
```

## Directory Purposes

**Sources/Sentry/**

- Purpose: Core Objective-C SDK implementation, crash reporting engine, low-level features
- Contains: 150+ implementation files (.m) with 176+ headers, C/C++ crash handling code
- Key files: `SentryClient.m` (event capture), `SentryHub.m` (scope management), `SentryCrash*.c` (crash handler)

**Sources/Sentry/include/**

- Purpose: Private headers for inter-module communication within SDK
- Contains: 176 private header files defining internal interfaces
- Pattern: `SentryFoo+Private.h` for additional private API on public classes

**Sources/Sentry/Public/**

- Purpose: Public headers exported in SDK umbrella framework
- Contains: 45 public headers defining stable SDK API
- Pattern: No implementation files, only declarations

**Sources/Sentry/Processors/**

- Purpose: Event processor implementations for transforming events
- Contains: Breadcrumb processor, event processor, client options processor

**Sources/Sentry/Profiling/**

- Purpose: CPU/memory profiling data collection (C++/ObjC hybrid)
- Contains: Sampling profiler, metric collection, timeseries building

**Sources/Swift/Helper/SentrySDK.swift**

- Purpose: Primary Swift API entry point
- Contains: `start(configureOptions:)`, `capture(event:)`, properties for span/logger/metrics
- Usage: Application code calls this static interface

**Sources/Swift/Core/Integrations/**

- Purpose: Core auto-instrumentation integrations
- Contains: ANR detection (V1 + V2), frame rate tracking, UI performance monitoring
- Pattern: Each integration is `SentryXyzIntegration.swift` implementing `SwiftIntegration` protocol

**Sources/Swift/Integrations/Performance/**

- Purpose: Transaction tracing and span creation
- Contains: UIViewController swizzling, transaction name mapping, profiling options
- Key: `SentryUIViewControllerSwizzling.swift` patches UIViewController lifecycle

**Sources/Swift/Integrations/Breadcrumbs/**

- Purpose: System event breadcrumb auto-capture
- Contains: UI event tracker, system event broadcaster, breadcrumb delegate

**Sources/Swift/Integrations/SessionReplay/**

- Purpose: Screen recording and replay functionality
- Contains: 26 files for mask generation, rrweb integration, replay API

**Sources/Swift/Networking/**

- Purpose: HTTP transport and network utilities
- Contains: Rate limiting, reachability checking, HTTP header parsing
- Pattern: Protocol definitions for testability; implementations in separate files

**Sources/Swift/Persistence/**

- Purpose: Local scope state persistence
- Contains: Persistent store for user, tags, context, extras, breadcrumbs
- Pattern: `SentryScopePersistentStore.swift` with category extensions per field type

**Tests/SentryTests/**

- Purpose: Main test suite covering SDK functionality
- Contains: 71+ test files with 1000+ test cases
- Organization: Mirrors source structure (Integrations/, Networking/, Protocol/, etc)

**Tests/Resources/**

- Purpose: Test data and fixtures
- Contains: JSON files, recorded HTTP responses, crash report samples

**TestSamples/**

- Purpose: Sample applications for manual testing and demonstration
- Contains: SwiftUI app samples, crash test apps

**develop-docs/**

- Purpose: Development-focused documentation
- Contains: Architecture guides, integration patterns, design decisions

## Key File Locations

**Entry Points:**

- `Sources/Swift/Helper/SentrySDK.swift`: SDK initialization and main public API
- `Sources/Sentry/SentrySDKInternal.m`: C++ bridge to Objective-C layer
- `Sources/Sentry/SentryHub.m`: Event capture and scope routing

**Configuration:**

- `Sources/Swift/Core/SentryOptions.swift`: Options definition (60+ properties)
- `Sources/Sentry/include/SentryOptionsInternal.h`: Internal options storage
- `Sources/Swift/Core/SentryOptionsObjC.swift`: Objective-C options wrapper

**Core Logic:**

- `Sources/Sentry/SentryClient.m`: Event processing pipeline (46k lines)
- `Sources/Sentry/SentryHub.m`: Session tracking, integration management (35k lines)
- `Sources/Sentry/SentryTransport.m`: Transport and envelope handling

**Transport:**

- `Sources/Sentry/SentryHttpTransport.m`: HTTP implementation with rate limiting
- `Sources/Swift/Networking/SentryReachability.swift`: Network detection
- `Sources/Swift/Networking/RateLimitParser.swift`: Rate limit header parsing

**Testing:**

- `Tests/SentryTests/Helper/`: Test utilities, mocks, fixtures
- `Tests/SentryTests/SentryClientTests.swift`: Core client tests (118k lines)
- `Tests/SentryTests/SentryHubTests.swift`: Hub and scope tests (77k lines)

**Integration Patterns:**

- `Sources/Swift/Integrations/SentryXyzIntegration.swift`: Each feature integration
- `Sources/Swift/Core/Integrations/Integrations.swift`: Integration installer
- `Sources/Swift/Integrations/Performance/SentryUIViewControllerSwizzling.swift`: Swizzling patterns

**Crash Handling:**

- `Sources/Sentry/SentryCrash.h`: Main crash reporter C API
- `Sources/Sentry/SentryCrashReportConverter.m`: Converting crash to Sentry event
- `Sources/Sentry/include/SentryCrashMonitor*.h`: Crash type monitors

**Serialization:**

- `Sources/Sentry/SentryMsgPackSerializer.m`: msgpack encoding
- `Sources/Swift/Protocol/Codable/`: Codable protocol definitions
- `Sources/Sentry/SentrySerialization.m`: JSON serialization helpers

## Naming Conventions

**Files:**

- Objective-C: `SentryFoo.{h,m}` or `SentryFoo+Bar.m` (categories)
- Swift: `SentryFoo.swift` (PascalCase, no prefix needed)
- Private headers: `SentryFoo+Private.h` or `SentryFooInternal.h`
- Headers in `include/`: Same naming as source, used for private APIs

**Directories:**

- Objective-C group: Feature name in PascalCase (e.g., `Profiling/`)
- Integration directories: Named `Sources/Swift/Integrations/FeatureName/`
- Category extensions: `SentryFoo+Bar.swift` in same directory as `SentryFoo.swift`

**Classes/Types:**

- Objective-C: `Sentry` prefix required: `SentryClient`, `SentryHub`, `SentryEvent`
- Swift: `Sentry` prefix for public types, optional for internal: `Options`, `SentryScope`
- Internal protocols: `Sentry*Delegate`, `Sentry*Protocol`, `Sentry*Provider`
- Integration classes: `Sentry*Integration` (e.g., `SentryNetworkTrackingIntegration`)

**Methods:**

- Objective-C: camelCase with descriptive verbs: `captureEvent:`, `startTransaction:operation:`
- Swift: camelCase: `capture(event:)`, `startTransaction(name:operation:)`
- Private methods: `_privateMethod:` or in extension with `+Private.h`

**Constants:**

- Objective-C: `SENTRY_*` (all caps) or `SentryFoo` prefix
- Swift: camelCase inside types: `Options.defaultDsn`

## Where to Add New Code

**New Feature/Integration:**

1. Create `Sources/Swift/Integrations/FeatureName/` directory
2. Implement `SentryFeatureNameIntegration.swift` conforming to `SwiftIntegration` protocol
3. Register in `Sources/Swift/Core/Integrations/Integrations.swift` `SentrySwiftIntegrationInstaller`
4. Add tests in `Tests/SentryTests/Integrations/SentryFeatureNameIntegrationTests.swift`
5. If needs Objective-C bridge: Create `Sources/Swift/Integrations/FeatureName/SentryFeatureNameObjC.m`

**New Event Processor:**

1. Implement processor class in `Sources/Sentry/Processors/SentryFooProcessor.m`
2. Add to processor list in `Sources/Sentry/SentryClient.m` initialization
3. Add tests in `Tests/SentryTests/Helper/SentryFooProcessorTests.swift`

**New Transport:**

1. Implement `Sources/Sentry/SentryFooTransport.m` conforming to `SentryTransport` protocol
2. Register in `Sources/Sentry/SentryTransportFactory.m`
3. Add conditional compilation if platform-specific

**New Breadcrumb Tracker:**

1. Implement tracker in `Sources/Swift/Integrations/Breadcrumbs/SentryFooTracker.swift`
2. Add to `SentrySystemEventBreadcrumbs.swift` array
3. Handle breadcrumb delegate callback for creation

**Test Files:**

- Unit tests: Mirror source directory in `Tests/SentryTests/`
- Naming: `SentryFooTests.swift` or `SentryFooTests.m`
- Fixtures: Place in `Tests/SentryTests/Resources/` or inline with `@available(iOS 13, *)` attributes

**Swift UI Helpers:**

- Place in `Sources/Swift/SentrySwiftUI/` if SwiftUI-specific
- Otherwise in `Sources/Swift/Core/Extensions/` for general extensions

**Helper Utilities:**

- Shared helpers: `Sources/Swift/Core/Helper/SentryFooHelper.swift`
- Extension methods: `Sources/Swift/Core/Extensions/Foo+Sentry.swift`

## Special Directories

**Sources/Sentry/Profiling/**

- Purpose: CPU/memory profiling (C++/Objective-C)
- Generated: No
- Committed: Yes
- Language: C++11, Objective-C++ (.cpp, .mm files)
- Note: Performance-critical code for sampling profiler

**Tests/SentryTests/Resources/**

- Purpose: Test fixtures, sample data, recorded HTTP responses
- Generated: No (created manually)
- Committed: Yes
- Usage: JSON files, crash report samples, HTTP recording files

**Tests/SentryTests/Helper/**

- Purpose: Test utilities, mock objects, test fixtures
- Generated: No
- Committed: Yes
- Key files: `SentryTestHTTPClient.m`, fixture builders, assertion helpers

**build/**, **.build/**, **BuildOutput/**

- Purpose: Build artifacts and intermediates
- Generated: Yes
- Committed: No (in .gitignore)
- Cleaned by: `make clean`

**Sentry.xcframework/**

- Purpose: Pre-built XCFramework for distribution
- Generated: Yes (by `make build-xcframework`)
- Committed: Yes (binary distribution artifact)
- Platforms: iOS, macOS, tvOS, watchOS, visionOS

**TestSamples/**

- Purpose: Sample applications for manual testing
- Generated: No
- Committed: Yes
- Build: Via Xcode projects included in directories

---

_Structure analysis: 2026-02-13_
