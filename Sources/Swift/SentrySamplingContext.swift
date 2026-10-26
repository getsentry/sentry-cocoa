internal import _SentryPrivate

/// Sampling context for Sentry samples.
@objc(SentrySamplingContext) 
@objcMembers
open class SamplingContext: NSObject {

    /// The transaction context.
    public let transactionContext: TransactionContext

    /// Custom data used for sampling.
    public let customSamplingContext: [String: Any] 
  
    /// Init a SentryTransactionSamplingContext.
    /// 
    /// - Parameter transactionContext: The context of the transaction being sampled.
    public init(transactionContext: TransactionContext) {
      self.transactionContext = transactionContext
      self.customSamplingContext = [:]
    }

    /// Init a SentryTransactionSamplingContext.
    /// 
    /// - Parameter transactionContext: The context of the transaction being sampled.
    /// - Parameter customSamplingContext: Custom data used for sampling.
    public init(transactionContext: TransactionContext, customSamplingContext: [String: Any]) {
      self.transactionContext = transactionContext
      self.customSamplingContext = customSamplingContext
    }
}
