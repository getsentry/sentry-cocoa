# Sentry SwiftLog Integration

A [SwiftLog](https://github.com/apple/swift-log) handler that forwards log entries to Sentry's structured logging system, automatically capturing application logs with full context including metadata, source location, and log levels.

> [!NOTE]
> This repo is a mirror of [github.com/getsentry/sentry-cocoa](https://github.com/getsentry/sentry-cocoa). The source code lives in `3rd-party-integrations/SentrySwiftLog/`. This allows users to import only what they need via SPM while keeping all integration code in the main repository.

## Installation

### Swift Package Manager

Add the following dependencies to your `Package.swift` or Xcode package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa-swiftlog", from: "1.0.0")
]
```

## Quick Start

```swift
import Sentry
import Logging

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
    options.enableLogs = true
}

var handler = SentryLogHandler(logLevel: .info)
handler.metadata["app_version"] = "1.0.0"
handler.metadata["environment"] = "production"

LoggingSystem.bootstrap { _ in handler }

let logger = Logger(label: "com.example.app")

logger.info("User logged in", metadata: ["userId": "12345"])
logger.error("Payment failed", metadata: ["errorCode": 500])
logger.warning("API rate limit approaching", metadata: ["remaining": 10])

logger.info("User action", metadata: [
    "userId": "12345",
    "action": "purchase"
])
```

## Configuration

### Log Level Threshold

Set the minimum log level for messages to be sent to Sentry. Messages below the configured threshold will be filtered out and not sent to Sentry.

```swift
let handler = SentryLogHandler(logLevel: .trace)
```

### Handler Metadata

Add metadata that will be included with all log entries. Handler metadata is merged with call-site metadata, with call-site metadata taking precedence.

```swift
var handler = SentryLogHandler(logLevel: .info)
handler.metadata["app_version"] = "1.0.0"
handler.metadata["environment"] = "production"
```

You can also access metadata using subscript syntax:

```swift
handler[metadataKey: "app_version"] = "1.0.0"
let version = handler[metadataKey: "app_version"]
```

## Log Level Mapping

`swift-log` levels are automatically mapped to Sentry log levels:

| swift-log Level | Sentry Log Level |
| --------------- | ---------------- |
| `.trace`        | `.trace`         |
| `.debug`        | `.debug`         |
| `.info`         | `.info`          |
| `.notice`       | `.info`          |
| `.warning`      | `.warn`          |
| `.error`        | `.error`         |
| `.critical`     | `.fatal`         |

## Metadata Handling

The handler supports all `swift-log` metadata types including strings, dictionaries, arrays, and string convertible types (numbers, booleans, etc.). All metadata is automatically prefixed with `swift-log.` in Sentry attributes (e.g., `swift-log.userId`, `swift-log.user.id`). See the Quick Start section above for examples of each metadata type.

## Automatic Attributes

The handler automatically includes the following attributes with every log entry:

- `sentry.origin`: `"auto.logging.swift-log"`
- `swift-log.level`: The original swift-log level
- `swift-log.source`: The log source
- `code.file.path`: The source file name
- `code.function.name`: The function name
- `code.line.number`: The line number

## Documentation

- [Sentry Cocoa SDK Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/)
- [SwiftLog Repo](https://github.com/apple/swift-log)

## License

This integration follows the same license as the Sentry Cocoa SDK. See the [LICENSE](https://github.com/getsentry/sentry-cocoa/blob/main/LICENSE.md) file for details.
