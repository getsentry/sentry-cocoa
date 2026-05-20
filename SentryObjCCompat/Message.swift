internal import SentrySwift
import Foundation

/// A log message that describes an event or error.
@objc(SOCSentryMessage)
public final class Message: NSObject {
    internal let wrapped: SentrySwift.SentryMessage

    internal init(_ wrapped: SentrySwift.SentryMessage) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(formatted: String) {
        self.wrapped = SentrySwift.SentryMessage(formatted: formatted)
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
