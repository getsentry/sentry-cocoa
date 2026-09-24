import Foundation
import Sentry

SentrySDK.start { options in
    options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
    options.debug = true
}

/**
 Some func to build a stacktrace.
 */
private func captureMessage() {
    let eventId = SentrySDK.capture(message: "Yeah captured a message")
    print("\(String(describing: eventId))")
    SentrySDK.flush(timeout: 5)
}

captureMessage()
