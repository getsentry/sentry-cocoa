internal import _SentryPrivate

// The Xcode target imports this name from SentryDefines.h. SwiftPM's SentryHeaders
// module only forward-declares SamplingContext, so the importer drops the typedef.
#if SWIFT_PACKAGE
/// A sampler callback. Return a sample rate from 0.0 through 1.0, or `nil` when no
/// sampling decision has been taken.
public typealias SentryTracesSamplerCallback = (SamplingContext) -> NSNumber?
#endif

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
