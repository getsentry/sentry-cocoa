// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc(SentryObjCTransaction) public final class SentryObjCTransaction: SentryObjCEvent {
    internal init(_ wrapped: Transaction) {
        super.init(wrapped)
    }

    internal var wrappedTransaction: Transaction {
        // swiftlint:disable:next force_cast
        wrapped as! Transaction
    }
}

// swiftlint:enable missing_docs
