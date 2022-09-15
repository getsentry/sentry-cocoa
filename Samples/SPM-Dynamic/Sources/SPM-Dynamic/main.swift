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

    // Some Delay to wait for sending the message
    let group = DispatchGroup()
    group.enter()
    let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])
    queue.asyncAfter(deadline: .now() + 2) {
        group.leave()
    }
    group.wait()
    
    print("\(String(describing: eventId))")
}

captureMessage()
