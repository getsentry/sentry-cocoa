# ``SentryCocoaLumberjack``

Send your CocoaLumberjack logs to Sentry.

## Overview

SentryCocoaLumberjack provides ``SentryCocoaLumberjackLogger``, a CocoaLumberjack logger that forwards [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) log messages to [Sentry Logs](https://docs.sentry.io/platforms/apple/logs/).
Every entry includes its source location and log level.

Start the Sentry SDK, then add the logger to CocoaLumberjack:

```swift
import CocoaLumberjackSwift
import Sentry
import SentryCocoaLumberjack

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
}

DDLog.add(SentryCocoaLumberjackLogger(), with: .info)

DDLogInfo("User logged in")
```

## Topics

### Logging

- ``SentryCocoaLumberjackLogger``
