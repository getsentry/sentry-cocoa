# ``SentryPulse``

Send your Pulse logs to Sentry.

## Overview

SentryPulse provides ``SentryPulse/SentryPulse``, an integration that forwards [Pulse](https://github.com/kean/Pulse) log messages to [Sentry Logs](https://docs.sentry.io/platforms/apple/logs/).
Every entry includes its source location and log level.

Start the Sentry SDK, then start forwarding messages from Pulse's `LoggerStore`:

```swift
import Pulse
import Sentry
import SentryPulse

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
}

SentryPulse.start()

let logger = LoggerStore.shared.makeLogger(label: "com.example.app")
logger.info("User logged in")
```

## Topics

### Integration

- ``SentryPulse/SentryPulse``
