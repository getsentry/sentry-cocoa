# Sentry Pulse Integration

A [Pulse](https://github.com/kean/Pulse) integration that automatically forwards log entries to Sentry's structured logging system, capturing application logs with full context including metadata, source location, and log levels.

> [!NOTE]
> This repo is a mirror of [github.com/getsentry/sentry-cocoa](https://github.com/getsentry/sentry-cocoa). The source code lives in `3rd-party-integrations/SentryPulse/`. This allows users to import only what they need via SPM while keeping all integration code in the main repository.

## Installation

### Swift Package Manager

Add the following dependencies to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.0.0"),
    .package(url: "https://github.com/getsentry/sentry-cocoa-pulse", from: "1.0.0"),
    .package(url: "https://github.com/kean/Pulse", from: "5.0.0")
]
```

Then add the required products to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Sentry", package: "sentry-cocoa"),
        .product(name: "SentryPulse", package: "sentry-cocoa-pulse"),
        .product(name: "Pulse", package: "Pulse")
    ]
)
```

## Quick Start

```swift
import Sentry
import Pulse
import SentryPulse

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
    options.enableLogs = true
}

SentryPulse.start()

let logger = LoggerStore.shared.makeLogger(label: "com.example.app")
logger.info("User logged in", metadata: ["userId": "12345"])
logger.error("Payment failed", metadata: ["errorCode": 500])
```

## Configuration

### Custom LoggerStore

By default, `SentryPulse.start()` uses `LoggerStore.shared`. You can specify a custom `LoggerStore`:

```swift
let customStore = try LoggerStore(storeURL: customURL, options: [.inMemory])
SentryPulse.start(loggerStore: customStore)
```

### Lifecycle Management

The integration automatically observes Pulse's `LoggerStore.events` publisher and forwards all `.messageStored` events to Sentry. You can stop the integration if needed:

```swift
SentryPulse.stop()
SentryPulse.start()
```

Calling `start()` multiple times has no effect - the integration is started only once.

## Log Level Mapping

Pulse log levels are automatically mapped to Sentry log levels:

| Pulse Level | Sentry Log Level |
| ----------- | ---------------- |
| `.trace`    | `.trace`         |
| `.debug`    | `.debug`         |
| `.info`     | `.info`          |
| `.notice`   | `.info`          |
| `.warning`  | `.warn`          |
| `.error`    | `.error`         |
| `.critical` | `.fatal`         |

## Metadata Handling

All Pulse metadata is automatically forwarded to Sentry with the `pulse.` prefix:

```swift
logger.info("User action", metadata: [
    "userId": "12345",
    "action": "purchase"
])
```

The metadata will appear in Sentry as `pulse.userId` and `pulse.action`.

Pulse metadata is already converted to `[String: String]` format before being forwarded, ensuring compatibility with Sentry's attribute system.

## Automatic Attributes

The integration automatically includes the following attributes with every log entry:

- `sentry.origin`: `"auto.logging.pulse"`
- `pulse.level`: The original Pulse level name
- `pulse.label`: The logger label
- `pulse.file`: The source file name (if available)
- `pulse.function`: The function name (if available)
- `pulse.line`: The line number

All Pulse metadata is prefixed with `pulse.` in Sentry attributes (e.g., `pulse.userId`, `pulse.action`).

## Documentation

- [Sentry Cocoa SDK Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/)
- [Pulse Repository](https://github.com/kean/Pulse)

## License

This integration follows the same license as the Sentry Cocoa SDK. See the [LICENSE](https://github.com/getsentry/sentry-cocoa/blob/main/LICENSE.md) file for details.
