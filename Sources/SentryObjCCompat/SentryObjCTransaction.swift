#if SDK_V10
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
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
#endif // SDK_V10
