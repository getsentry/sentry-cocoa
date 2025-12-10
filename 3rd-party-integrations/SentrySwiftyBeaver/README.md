# Sentry SwiftyBeaver Integration

A [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) destination that forwards log entries to Sentry's structured logging system, automatically capturing application logs with full context including metadata, source location, and log levels.

> [!NOTE]
> This repo is a mirror of [github.com/getsentry/sentry-cocoa](https://github.com/getsentry/sentry-cocoa). The source code lives in `3rd-party-integrations/SentrySwiftyBeaver/`. This allows users to import only what they need via SPM while keeping all integration code in the main repository.

## Installation

### Swift Package Manager

Add the following dependencies to your `Package.swift` or Xcode package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa-swiftybeaver", from: "1.0.0")
]
```

## Quick Start

```swift
import Sentry
import SwiftyBeaver

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
    options.logsEnabled = true
}

let log = SwiftyBeaver.self
let sentryDestination = SentryDestination()
log.addDestination(sentryDestination)

log.info("User logged in", context: ["userId": "12345", "sessionId": "abc"])
```

## Configuration

### Log Level Threshold

Set the minimum log level for messages to be sent to Sentry using SwiftyBeaver's built-in `minLevel` property. Messages below the configured threshold will be filtered out and not sent to Sentry.

```swift
let sentryDestination = SentryDestination()
sentryDestination.minLevel = .info
log.addDestination(sentryDestination)
```

## Log Level Mapping

SwiftyBeaver levels are automatically mapped to Sentry log levels:

| SwiftyBeaver Level | Sentry Log Level |
| ------------------ | ---------------- |
| `.verbose`         | `.trace`         |
| `.debug`           | `.debug`         |
| `.info`            | `.info`          |
| `.warning`         | `.warn`          |
| `.error`           | `.error`         |
| `.critical`        | `.fatal`         |
| `.fault`           | `.fatal`         |

## Context Handling

The destination supports SwiftyBeaver's `context` parameter for additional metadata:

### Dictionary Context

When `context` is provided as a `[String: Any]` dictionary, each key-value pair is added as an individual Sentry log attribute with the prefix `swiftybeaver.context.{key}`.

```swift
log.info("User action", context: [
    "userId": "12345",
    "action": "purchase",
    "isActive": true,
    "errorCode": 500,
    "amount": 99.99
])
```

Supported types in dictionary context:

- Strings
- Numbers (Int, Double, Float)
- Booleans
- Arrays (converted to string representation)

### Non-Dictionary Context

For non-dictionary contexts, the entire context is converted to a string attribute `swiftybeaver.context`.

```swift
log.info("Test message", context: "simple string context")
```

## Automatic Attributes

The destination automatically includes the following attributes with every log entry:

- `sentry.origin`: `"auto.logging.swiftybeaver"`
- `swiftybeaver.level`: The original SwiftyBeaver level (as raw value)
- `swiftybeaver.thread`: The thread identifier
- `swiftybeaver.file`: The source file name
- `swiftybeaver.function`: The function name
- `swiftybeaver.line`: The line number

## Documentation

- [Sentry Cocoa SDK Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/)
- [SwiftyBeaver Repo](https://github.com/SwiftyBeaver/SwiftyBeaver)

## License

This integration follows the same license as the Sentry Cocoa SDK. See the [LICENSE](https://github.com/getsentry/sentry-cocoa/blob/main/LICENSE.md) file for details.
