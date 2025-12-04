# Sentry Swift-Log Integration

A `swift-log` handler that forwards log entries to Sentry's structured logging system, automatically capturing application logs with full context including metadata, source location, and log levels.

## Installation

### Swift Package Manager

Add the following dependencies to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.0.0"),
    .package(url: "https://github.com/getsentry/sentry-cocoa-swiftlog", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.0")
]
```

Then add the required products to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Sentry", package: "sentry-cocoa"), // Required for SentrySDK initialization
        .product(name: "SentrySwiftLog", package: "sentry-cocoa-swiftlog"),
        .product(name: "Logging", package: "swift-log") // Required for Logger and LoggingSystem
    ]
)
```

## Quick Start

### 1. Initialize Sentry SDK

First, initialize the Sentry SDK with logs enabled:

```swift
import Sentry

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
    options.enableLogs = true // Required for logging integration
}
```

### 2. Register SentryLogHandler

Bootstrap the logging system with `SentryLogHandler`:

```swift
import Logging

LoggingSystem.bootstrap { _ in
    return SentryLogHandler(logLevel: .info)
}
```

### 3. Use the Logger

Create and use loggers throughout your application:

```swift
let logger = Logger(label: "com.example.app")

logger.info("User logged in", metadata: ["userId": "12345"])
logger.error("Payment failed", metadata: ["errorCode": 500])
logger.warning("API rate limit approaching", metadata: ["remaining": 10])
```

## Configuration

### Log Level Threshold

Set the minimum log level for messages to be sent to Sentry:

```swift
// Only send info level and above
let handler = SentryLogHandler(logLevel: .info)

// Send all logs including trace and debug
let handler = SentryLogHandler(logLevel: .trace)
```

Messages below the configured threshold will be filtered out and not sent to Sentry.

### Handler Metadata

Add metadata that will be included with all log entries:

```swift
var handler = SentryLogHandler(logLevel: .info)
handler.metadata["app_version"] = "1.0.0"
handler.metadata["environment"] = "production"

LoggingSystem.bootstrap { _ in handler }
```

Handler metadata is merged with call-site metadata, with call-site metadata taking precedence.

### Metadata Subscript Access

You can also access metadata using subscript syntax:

```swift
var handler = SentryLogHandler(logLevel: .info)
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

The handler supports all `swift-log` metadata types:

### String Metadata

```swift
logger.info("User action", metadata: [
    "userId": "12345",
    "action": "purchase"
])
```

### Dictionary Metadata

```swift
logger.info("User profile", metadata: [
    "user": [
        "id": "12345",
        "name": "John Doe"
    ]
])
```

### Array Metadata

```swift
logger.info("Tags", metadata: [
    "tags": ["production", "api", "v2"]
])
```

### String Convertible Metadata

```swift
logger.info("Metrics", metadata: [
    "count": 42,
    "enabled": true,
    "score": 3.14159
])
```

All metadata is automatically prefixed with `swift-log.` in Sentry attributes (e.g., `swift-log.userId`, `swift-log.user.id`).

## Automatic Attributes

The handler automatically includes the following attributes with every log entry:

- `sentry.origin`: `"auto.logging.swift-log"`
- `swift-log.level`: The original swift-log level
- `swift-log.source`: The log source
- `swift-log.file`: The source file name
- `swift-log.function`: The function name
- `swift-log.line`: The line number

## Documentation

- [Sentry Cocoa SDK Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/)

## License

This integration follows the same license as the Sentry Cocoa SDK. See the [LICENSE](https://github.com/getsentry/sentry-cocoa/blob/main/LICENSE.md) file for details.
