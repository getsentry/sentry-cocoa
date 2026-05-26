// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCSamplingContext: NSObject {
    internal let wrapped: SamplingContext

    internal init(_ wrapped: SamplingContext) {
        self.wrapped = wrapped
    }

    @objc public init(transactionContext: SentryObjCTransactionContext) {
        self.wrapped = SamplingContext(transactionContext: transactionContext.wrappedTransaction)
    }

    @objc public init(transactionContext: SentryObjCTransactionContext, customSamplingContext: [String: Any]) {
        self.wrapped = SamplingContext(transactionContext: transactionContext.wrappedTransaction, customSamplingContext: customSamplingContext)
    }

    @objc public var transactionContext: SentryObjCTransactionContext {
        SentryObjCTransactionContext(wrapped.transactionContext)
    }

    @objc public var customSamplingContext: [String: Any]? {
        wrapped.customSamplingContext
    }
}

// swiftlint:enable missing_docs
