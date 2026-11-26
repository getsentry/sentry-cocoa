import Foundation

/// Makes the sampling decisions for traces and profile sessions.
@_spi(Private) @objc public final class SentrySampling: NSObject {

    /// Determines whether a trace should be sampled based on the context and options.
    @objc(sampleTrace:options:)
    public static func sampleTrace(_ context: SamplingContext, options: Options?) -> SentrySamplerDecision {
        let transactionContext = context.transactionContext

        // check this transaction's sampling decision, if already decided
        if transactionContext.sampled != .undecided {
            return SentrySamplerDecision(
                decision: transactionContext.sampled,
                forSampleRate: transactionContext.sampleRate,
                withSampleRand: transactionContext.sampleRand
            )
        }

        if let callbackRate = samplerCallbackRate(options?.tracesSampler, context: context) {
            return calcSample(callbackRate)
        }

        // check the _parent_ transaction's sampling decision, if any
        if transactionContext.parentSampled != .undecided {
            return SentrySamplerDecision(
                decision: transactionContext.parentSampled,
                forSampleRate: transactionContext.sampleRate,
                withSampleRand: transactionContext.sampleRand
            )
        }

        return calcSampleFromNumericalRate(options?.tracesSampleRate)
    }

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// Determines whether a profile session should be sampled for the given sample rate.
    @objc(sampleProfileSession:)
    public static func sampleProfileSession(_ sessionSampleRate: Float) -> SentrySamplerDecision {
        return calcSampleFromNumericalRate(NSNumber(value: sessionSampleRate))
    }
#endif // !(os(watchOS) || os(tvOS) || os(visionOS))

    /// Returns the sample rate if the sampler callback is defined and returns a valid value,
    /// `nil` otherwise.
    private static func samplerCallbackRate(_ callback: SentryTracesSamplerCallback?, context: SamplingContext) -> NSNumber? {
        guard let callback, let callbackRate = callback(context), callbackRate.isValidSampleRate() else {
            return nil
        }
        return callbackRate
    }

    private static func calcSample(_ rate: NSNumber) -> SentrySamplerDecision {
        let random = SentryDependencyContainer.sharedInstance().random.nextNumber()
        let decision: SentrySampleDecision = random <= rate.doubleValue ? .yes : .no
        return SentrySamplerDecision(decision: decision, forSampleRate: rate, withSampleRand: NSNumber(value: random))
    }

    private static func calcSampleFromNumericalRate(_ rate: NSNumber?) -> SentrySamplerDecision {
        guard let rate else {
            return SentrySamplerDecision(decision: .no, forSampleRate: nil, withSampleRand: nil)
        }
        return calcSample(rate)
    }
}
