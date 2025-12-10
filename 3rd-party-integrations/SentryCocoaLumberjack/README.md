# Sentry CocoaLumberjack Integration

A [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) logger that forwards log entries to Sentry's structured logging system, automatically capturing application logs with full context including source location, thread information, and log levels.

> [!NOTE]
> This repo is a mirror of [github.com/getsentry/sentry-cocoa](https://github.com/getsentry/sentry-cocoa). The source code lives in `3rd-party-integrations/SentryCocoaLumberjack/`. This allows users to import only what they need via SPM while keeping all integration code in the main repository.

## Installation

### Swift Package Manager

Add the following dependencies to your `Package.swift` or Xcode package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa-cocoalumberjack", from: "1.0.0")
]
```

## Quick Start

```swift
import Sentry
import SentryCocoaLumberjack
import CocoaLumberjackSwift

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
    options.enableLogs = true
}

DDLog.add(SentryCocoaLumberjackLogger(), with: .info)

DDLogInfo("User logged in")
DDLogError("Payment failed")
DDLogWarn("API rate limit approaching")
DDLogDebug("Processing request")
DDLogVerbose("Detailed trace information")
```

## Configuration

### Log Level Threshold

Use CocoaLumberjack's built-in filtering API when adding the logger to set the minimum log level for messages to be sent to Sentry:

```swift
// Only send error logs to Sentry
DDLog.add(SentryCocoaLumberjackLogger(), with: .error)
```

## Log Level Mapping

CocoaLumberjack log levels are automatically mapped to Sentry log levels:

| CocoaLumberjack Level | Sentry Log Level |
| --------------------- | ---------------- |
| `.error`              | `.error`         |
| `.warning`            | `.warn`          |
| `.info`               | `.info`          |
| `.debug`              | `.debug`         |
| `.verbose`            | `.trace`         |

## Automatic Attributes

The logger automatically includes the following attributes with every log entry:

- `sentry.origin`: `"auto.logging.cocoalumberjack"`
- `cocoalumberjack.level`: The original CocoaLumberjack log level (error, warning, info, debug, verbose)
- `cocoalumberjack.file`: The source file name
- `cocoalumberjack.function`: The function name
- `cocoalumberjack.line`: The line number
- `cocoalumberjack.context`: The log context (integer)
- `cocoalumberjack.timestamp`: The log timestamp
- `cocoalumberjack.threadID`: The thread ID
- `cocoalumberjack.threadName`: The thread name (if available)
- `cocoalumberjack.queueLabel`: The dispatch queue label (if available)

## Documentation

- [Sentry Cocoa SDK Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/)
- [CocoaLumberjack Repo](https://github.com/CocoaLumberjack/CocoaLumberjack)

## License

This integration follows the same license as the Sentry Cocoa SDK. See the [LICENSE](https://github.com/getsentry/sentry-cocoa/blob/main/LICENSE.md) file for details.
