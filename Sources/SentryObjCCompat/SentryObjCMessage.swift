// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCMessage: NSObject {
    internal let wrapped: SentryMessage

    internal init(_ wrapped: SentryMessage) {
        self.wrapped = wrapped
    }

    @objc public init(formatted: String) {
        self.wrapped = SentryMessage(formatted: formatted)
    }

    @objc public var formatted: String {
        wrapped.formatted
    }

    @objc public var message: String? {
        get { wrapped.message }
        set { wrapped.message = newValue }
    }

    @objc public var params: [String]? {
        get { wrapped.params }
        set { wrapped.params = newValue }
    }
}

// swiftlint:enable missing_docs
