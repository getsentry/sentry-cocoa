// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCHint) public final class SentryObjCHint: NSObject {
    internal let wrapped: Hint

    internal init(_ wrapped: Hint) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = Hint()
    }

    @objc public init(error: NSError) {
        self.wrapped = Hint(error: error)
    }

    @objc public init(exception: NSException) {
        self.wrapped = Hint(exception: exception)
    }

    @objc public var originalError: NSError? {
        get { wrapped.originalError as NSError? }
        set { wrapped.originalError = newValue }
    }

    @objc public var originalException: NSException? {
        get { wrapped.originalException }
        set { wrapped.originalException = newValue }
    }

    @objc public var attachments: [SentryObjCAttachment] {
        get { wrapped.attachments.map { SentryObjCAttachment($0) } }
        set { wrapped.attachments = newValue.map(\.wrapped) }
    }

    @objc public func setHintValue(_ value: Any?, forKey key: String) {
        if let value = value {
            wrapped.setHintValue(value, forKey: key)
        } else {
            wrapped.removeHintValue(forKey: key)
        }
    }

    @objc public func hintValue(forKey key: String) -> Any? {
        wrapped.hintValue(forKey: key)
    }

    @objc public func removeHintValue(forKey key: String) {
        wrapped.removeHintValue(forKey: key)
    }
}

// swiftlint:enable missing_docs
