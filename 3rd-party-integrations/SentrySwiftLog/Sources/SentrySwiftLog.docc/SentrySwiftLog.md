# ``SentrySwiftLog``

Send your swift-log logs to Sentry.

## Overview

SentrySwiftLog provides ``SentryLogHandler``, a [swift-log](https://github.com/apple/swift-log) `LogHandler` that forwards log entries to [Sentry Logs](https://docs.sentry.io/platforms/apple/logs/).
Every entry includes its metadata, source location, log level, and the label of the logger that wrote it.

Start the Sentry SDK, then bootstrap the logging system with the handler:

```swift
import Logging
import Sentry
import SentrySwiftLog

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
}

LoggingSystem.bootstrap { label in
    SentryLogHandler(label: label, logLevel: .info)
}

let logger = Logger(label: "com.example.app")
logger.info("User logged in", metadata: ["userId": "12345"])
```

## Topics

### Logging

- ``SentryLogHandler``
