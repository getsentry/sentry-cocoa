internal import SentrySwift
import Foundation

/// Context passed to the `tracesSampler` callback.
@objc(SOCSentrySamplingContext)
public final class SamplingContext: NSObject {
    internal let wrapped: SentrySwift.SamplingContext

    internal init(_ wrapped: SentrySwift.SamplingContext) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(transactionContext: TransactionContext) {
        self.wrapped = SentrySwift.SamplingContext(transactionContext: transactionContext.wrapped)
        super.init()
    }

    @objc public init(transactionContext: TransactionContext, customSamplingContext: [String: Any]) {
        self.wrapped = SentrySwift.SamplingContext(
            transactionContext: transactionContext.wrapped,
            customSamplingContext: customSamplingContext
        )
        super.init()
    }

    @objc public var transactionContext: TransactionContext {
        TransactionContext(wrapped.transactionContext)
    }

    @objc public var customSamplingContext: [String: Any]? {
        wrapped.customSamplingContext
    }
}
