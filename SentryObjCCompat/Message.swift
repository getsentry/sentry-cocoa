@_implementationOnly import Sentry
import Foundation

/// A log message that describes an event or error.
@objc(SentryCompatMessage)
public final class Message: NSObject {
    internal let wrapped: Sentry.SentryMessage

    internal init(_ wrapped: Sentry.SentryMessage) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(formatted: String) {
        self.wrapped = Sentry.SentryMessage(formatted: formatted)
        super.init()
    }

    @objc public var formatted: String { wrapped.formatted }

    @objc public var message: String? {
        get { wrapped.message }
        set { wrapped.message = newValue }
    }

    @objc public var params: [String]? {
        get { wrapped.params }
        set { wrapped.params = newValue }
    }
}
