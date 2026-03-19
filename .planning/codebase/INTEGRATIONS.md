# External Integrations

**Analysis Date:** 2026-03-19

## APIs & External Services

**Sentry API:**

- Service: Sentry error tracking backend
- What it's used for: Event capture, envelope submission, metrics collection, session tracking
  - SDK/Client: URLSession (no external SDK, native implementation)
  - Auth: X-Sentry-Auth header with DSN credentials (public key + optional secret key)
  - Endpoint: Configured via DSN with format `https://<key>:<secret>@sentry.io/<project-id>`
  - File: `Sources/Swift/Tools/SentryURLRequestFactory.swift` - Constructs authenticated requests

**Sentry Distribution API:**

- Service: Distribution updates and version checking
- What it's used for: App distribution updates and variant selection
  - Client: URLSession with Bearer token authentication
  - Auth env var: Requires Bearer token in Authorization header
  - File: `Sources/SentryDistribution/Updater.swift`

## Data Storage

**Databases:**

- CoreData - Optional performance tracing integration
  - Integration: `Sources/Swift/Integrations/Performance/CoreData/SentryCoreDataTrackingIntegration.swift`
  - Client: Native CoreData framework
  - Tracing: Tracks NSFetchRequest, NSManagedObject operations
  - Control: `options.enableCoreDataTracing` (defaults true)

**File Storage:**

- Local filesystem only - on-device envelope/cache storage
  - Location: Application's Documents/Caches directory
  - Manager: SentryFileManager (ObjC implementation)
  - Purpose: Queue envelopes for retry and offline support
  - File: `Sources/Sentry/SentryFileManagerHelper.m`

**Caching:**

- In-memory cache - Rate limiting, session state, scope persistence
  - Default max items: 30 envelopes (configurable via `options.maxCacheItems`)
  - Breadcrumbs: In-memory circular buffer (default 100, configurable)
  - Scope persistence: UserDefaults for cross-app-launch state

## Authentication & Identity

**Auth Provider:**

- Custom (DSN-based) - No external identity provider
  - Implementation: Public/private key pair from DSN URI
  - Format: `protocol://publicKey:secretKey@host:port/projectId`
  - Headers: X-Sentry-Auth with version, client, key, secret
  - File: `Sources/Swift/SentryDsn.swift`

**Session Management:**

- Custom session tracking - No OAuth/OIDC integration
  - File: `Sources/Swift/SentrySession.swift`
  - Purpose: Tracks user sessions with unique session IDs and release info

## Monitoring & Observability

**Error Tracking:**

- Sentry (self-referential) - SDK sends events back to Sentry
  - Event types: Errors, crashes, exceptions, transactions, logs
  - Batching: Envelope format with gzip compression
  - File: `Sources/Swift/Networking/` - HTTP transport

**Logs:**

- Console/os_log - Debug logging via SentryLogger
  - Structured logging API: `SentrySDK.logger` with attributes
  - File: `Sources/Swift/Tools/SentryLogger.swift`
  - SDK logs controlled by `options.debug` flag
  - Format: Custom SentryLog protocol with level (trace/debug/info/warn/error/fatal)

**Profiling:**

- Sampling profiler (custom) - Continuous profiling for performance monitoring
  - Implementation: C++/ObjC++ at `Sources/Sentry/Profiling/`
  - Frame tracking: CADisplayLink for screen refresh integration
  - Thread sampling: Native thread API via SentryCppHelper
  - File: `Sources/Sentry/Profiling/SentryProfilerState.mm`

## CI/CD & Deployment

**Hosting:**

- GitHub Releases - Binary distribution via XCFramework
  - URL pattern: `https://github.com/getsentry/sentry-cocoa/releases/download/<version>/<variant>.xcframework.zip`
  - Checksums: SHA256 verification in Package.swift for each variant
  - Variants: Static, Dynamic, WithARM64e, WithoutUIKitOrAppKit

**CI Pipeline:**

- GitHub Actions - Automated build, test, lint
  - Workflows: `build.yml`, `fast-pr-checks.yml`, `integration-test.yml`, etc.
  - On: main branch, release branches, pull requests
  - Concurrency: Prevents duplicate builds; cancels PR builds on new commits
  - Tools: Fastlane, xcbeautify, slather, xcpretty

**Build Outputs:**

- XCFrameworks - Multi-platform binary distribution
- SPM packages - Source or binary distribution
- CocoaPods spec - Legacy package (deprecated)

## Network Communication

**Outgoing HTTP/HTTPS:**

- POST to Sentry API endpoints (envelopes, events, metrics, sessions)
  - Protocol: HTTPS (enforced via DSN validation)
  - Format: Sentry Envelope format with gzip compression
  - Headers: X-Sentry-Auth, Content-Type (application/x-sentry-envelope), User-Agent
  - Timeout: 15 seconds per request (SentryURLRequestFactory.swift)
  - Rate limiting: X-Sentry-Rate-Limits header parsing and enforcement

**Incoming Webhooks:**

- None detected - SDK is receive-only for configuration

## Third-Party Integrations

**Hybrid SDK Support:**

- Sentry React Native - Via PrivateSentrySDKOnly SPI
- Sentry Flutter - Via PrivateSentrySDKOnly SPI
- Sentry .NET - Via PrivateSentrySDKOnly SPI
- Sentry Unity - Via PrivateSentrySDKOnly SPI
  - File: `Sources/Swift/Protocol/PrivateSentrySDKOnly.swift`
  - Purpose: Allows JS/native bridge SDKs to hook into event processing

**Performance & Telemetry:**

- App Startup Tracking - Built-in integration
- Network tracing - URLSession swizzling (optional)
- View/UI tracing - UIViewController swizzling (optional)
- Screen frames - CADisplayLink integration
- MetricKit - Optional CrashReport/CPU/Memory metrics (macOS/iOS)
  - File: `Sources/Swift/Core/MetricKit/`

**Crash Reporting:**

- SentryCrash (fork of KSCrash) - Built-in signal/exception handling
  - Features: Crash dumps, uncaught exceptions, SIGTERM signals
  - Location: `Sources/SentryCrash/`
  - Control: `options.enableCrashHandler` (defaults true, auto-disabled with debugger)

**Session Replay:**

- Custom implementation (not external service)
  - Features: Screen capture, view hierarchy, privacy masking
  - Files: `Sources/Swift/Integrations/SessionReplay/`
  - Masks: PII redaction for sensitive views

## Environment Configuration

**Required env vars:**

- `SENTRY_DSN` - Sentry endpoint credentials (checked on macOS at startup)

**Secrets location:**

- `.env` file - Contains GITHUB_PAT for CI only
- Per CLAUDE.md: Never committed to git, only for GitHub Actions CI

**Build-time configuration:**

- Preprocessor flags: `SENTRY_NO_UI_FRAMEWORK`, `SENTRY_TARGET_PROFILING_SUPPORTED`
- Feature flags: Can disable crash handling, network breadcrumbs, session tracking, profiling per-platform

## Spotlights & Developer Tools

**Local Debug Transport:**

- Spotlight (optional) - Local WebSocket transport for debugging
  - File: `Sources/Sentry/SentrySpotlightTransport.m`
  - Purpose: Route events to Spotlight for local inspection (not production)

---

_Integration audit: 2026-03-19_
