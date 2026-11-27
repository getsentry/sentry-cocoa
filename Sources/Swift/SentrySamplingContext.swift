internal import _SentryPrivate

// Declare this alias in both builds: SwiftPM's Clang importer drops the Objective-C
// typedef because SentryHeaders only forward-declares SamplingContext.
/// A sampler callback. Return a sample rate from 0.0 through 1.0, or `nil` when no
/// sampling decision has been taken.
public typealias SentryTracesSamplerCallback = (SamplingContext) -> NSNumber?

/// Sampling context for Sentry samples.
@objc(SentrySamplingContext) 
@objcMembers
open class SamplingContext: NSObject {

    /// The transaction context.
    public let transactionContext: TransactionContext

    /// Custom data used for sampling.
    public let customSamplingContext: [String: Any]?
  
    /// Init a SentryTransactionSamplingContext.
    /// 
    /// - Parameter transactionContext: The context of the transaction being sampled.
    public init(transactionContext: TransactionContext) {
      self.transactionContext = transactionContext
      self.customSamplingContext = nil
    }

    /// Init a SentryTransactionSamplingContext.
    /// 
    /// - Parameter transactionContext: The context of the transaction being sampled.
    /// - Parameter customSamplingContext: Custom data used for sampling.
    public init(transactionContext: TransactionContext, customSamplingContext: [String: Any]?) {
      self.transactionContext = transactionContext
      self.customSamplingContext = customSamplingContext
    }
}
