# External Integrations

**Analysis Date:** 2026-02-13

## APIs & External Services

**Sentry Backend Service:**

- Primary error/crash reporting endpoint
- SDK: HTTP transport via native `NSURLSession`
- Auth: DSN (Data Source Name) - extracted and parsed into project key + URL
- Configuration: `SentryHttpTransport` (`Sources/Sentry/SentryHttpTransport.m`)
- Request building: `SentryNSURLRequestBuilder` (`Sources/Swift/Networking/SentryNSURLRequestBuilder.swift`)

**Spotlight (Optional Debug Tool):**

- Local debugger integration for development
- URL: Configurable via `SentryOptions.spotlightUrl`
- SDK: HTTP transport via `SentrySpotlightTransport` (`Sources/Sentry/SentrySpotlightTransport.m`)
- Purpose: Real-time debug event visualization without leaving Xcode
- Optional feature controlled by `enableSpotlight` boolean flag

**Release Distribution Service (Optional):**

- Separate module: `SentryDistribution` (`Sources/SentryDistribution/`)
- Purpose: Check for and fetch release updates
- Implementation: Native `URLSession` via `URLSession+Distribute.swift`
- Models: `CheckForUpdateParams`, `UpdateCheckResponse`, `ReleaseInfo`

## Data Storage

**Databases:**

- None - SDK does not use traditional databases (SQLite, Realm, Core Data, etc.)
- File-based persistence: `SentryFileManager` stores serialized envelopes locally (`Sources/Sentry/SentryFileManager.m`)
- Serialization: JSON-based via `SentrySerialization` (`Sources/Sentry/SentrySerialization.m`)
- Purpose: Queue events for delivery when offline

**File Storage:**

- Local filesystem only via `SentryFileManager`
- Envelope data stored as temporary files pending transmission
- No integration with cloud storage services (S3, etc.)

**Caching:**

- In-memory rate limiting via `SentryRateLimits` interface
- Implementations: `DefaultRateLimits`, `SentryEnvelopeRateLimit`
- No Redis or Memcached integration

## Authentication & Identity

**Auth Provider:**

- Custom DSN-based authentication (no external OAuth/OIDC)
- DSN Format: `https://<publicKey>:<secretKey>@o<orgId>.ingest.sentry.io/<projectId>`
- Implementation: `SentryDsn` parser (`Sources/Sentry/SentryDsn.m`)
- Public key included in envelope headers as `sentry-client-requests`
- No user authentication required - app-level authentication only

**Authorization:**

- None - SDK sends to configured Sentry project only
- No permission checking; all events sent if DSN is valid and SDK enabled

## Monitoring & Observability

**Error Tracking:**

- Sentry backend itself (primary service)
- No integration with Datadog, New Relic, or other APM tools

**Logs:**

- Internal logging via `SentrySDKLog` (`Sources/Swift/Tools/SentrySDKLog.swift`)
- Debug output to console when `SentryOptions.debug = true`
- Log level controlled by `diagnosticLevel` (defaults to debug)
- No external log aggregation service

**Telemetry:**

- Internal telemetry buffer: `SentryTelemetryBuffer` (`Sources/Swift/Tools/TelemetryBuffer/`)
- Metrics integration: `SentryMetricsIntegration` (`Sources/Swift/Integrations/Metrics/SentryMetricsIntegration.swift`)
- No integration with CloudWatch, Stackdriver, or similar services

## CI/CD & Deployment

**Hosting:**

- Distributed via GitHub Releases (XCFramework artifacts)
- CocoaPods.org (CocoaPods distribution)
- Swift Package Index (SPM metadata)

**CI Pipeline:**

- GitHub Actions - 35 workflow files in `.github/workflows/`
- Key workflows:
  - `build.yml` - Multi-platform builds
  - `integration-test.yml` - Integration testing
  - `api-stability.yml` - API surface validation
  - `codeql-analysis.yml` - SAST security scanning
  - `lint-*.yml` - Code quality checks (SwiftLint, Clang-Format, dprint, ShellCheck)
  - `fast-pr-checks.yml` - Quick PR validation

**Release Process:**

- Version management via `VersionBump` utility (`Utils/VersionBump/.build/`)
- Tag-based releases with automated artifact generation
- CocoaPods and SPM specs updated automatically

## Environment Configuration

**Required env vars:**

- `SENTRY_DSN` - Project authentication (loaded on macOS in `Sources/Swift/Options.swift:8`)
- No other mandatory environment variables for SDK operation

**Optional env vars (via CI/development):**

- `COVERAGE_REPORT_SERVICE` - Code coverage service (CircleCI integration possible)
- Standard CI environment variables (GitHub Actions context)

**Secrets location:**

- `.env` file exists (not committed, noted in `.gitignore`)
- Environment variables for CI: GitHub Secrets
- No hardcoded secrets in source code

**Configuration via Code:**

- DSN: `Options.dsn = "https://..."`
- Spotlight: `Options.enableSpotlight = true/false`, `Options.spotlightUrl = "..."`
- Sentry backend URL: Derived from DSN parsing
- All configuration done in `Options` class (`Sources/Swift/Options.swift`)

## Webhooks & Callbacks

**Incoming:**

- Test server accepts webhook payloads (`test-server/Sources/App/routes.swift`)
- Receives Sentry envelope submissions from SDK
- No public webhook endpoint exposed by SDK itself

**Outgoing:**

- None - SDK does not initiate outbound webhooks
- SDK sends envelopes (one-way HTTP POST) to Sentry
- Optional distribution update checks to release service

## Network Behavior

**HTTP Client:**

- Native `NSURLSession` (iOS/macOS standard)
- Implementation: `SentryQueueableRequestManager` (`Sources/Sentry/SentryQueueableRequestManager.m`)
- Protocol: HTTP/2 capable (via native NSURLSession support)
- Custom headers: `sentry-client-requests`, envelope API header with client name/version

**Rate Limiting:**

- Implements Sentry Relay rate limit headers
- Parsing: `RateLimitParser`, `RetryAfterHeaderParser` (`Sources/Swift/Networking/`)
- Respects `Retry-After` headers from backend
- Client-side rate limit tracking via `RateLimits` interface

**Offline Support:**

- Reachability detection via `SentryReachability` (`Sources/Sentry/SentryReachability.m`)
- Queues events to disk when offline
- Resends from queue when connectivity restored
- Rate limit state persisted across app restarts

**Network Tracking:**

- Optional network span creation for HTTP traffic
- Monitors via `NSURLSession` delegate hooking
- Traces GraphQL operations (operation name extraction)
- Integration: `SentryNetworkTracker` (`Sources/Sentry/SentryNetworkTracker.m`)

---

_Integration audit: 2026-02-13_
