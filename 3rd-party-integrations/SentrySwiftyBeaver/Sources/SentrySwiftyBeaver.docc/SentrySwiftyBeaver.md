# ``SentrySwiftyBeaver``

Send your SwiftyBeaver logs to Sentry.

## Overview

SentrySwiftyBeaver provides ``SentryDestination``, a SwiftyBeaver destination that forwards [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) log messages to [Sentry Logs](https://docs.sentry.io/platforms/apple/logs/).
Every entry includes its source location and log level.

Start the Sentry SDK, then add the destination to SwiftyBeaver:

```swift
import Sentry
import SentrySwiftyBeaver
import SwiftyBeaver

SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
    options.logsEnabled = true
}

let log = SwiftyBeaver.self
log.addDestination(SentryDestination())

log.info("User logged in")
```

## Topics

### Logging

- ``SentryDestination``
