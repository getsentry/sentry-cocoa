@_implementationOnly import Sentry
import Foundation

/// Context passed to the `tracesSampler` callback.
@objc(SentryCompatSamplingContext)
public final class SamplingContext: NSObject {
    internal let wrapped: Sentry.SamplingContext

    internal init(_ wrapped: Sentry.SamplingContext) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(transactionContext: TransactionContext) {
        self.wrapped = Sentry.SamplingContext(transactionContext: transactionContext.wrapped)
        super.init()
    }

    @objc public init(transactionContext: TransactionContext, customSamplingContext: [String: Any]) {
        self.wrapped = Sentry.SamplingContext(
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
