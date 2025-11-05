#import "SentrySampling.h"
#import "SentryInternalDefines.h"
#import "SentryOptionsInternal.h"
#import "SentrySampleDecision.h"
#import "SentrySamplerDecision.h"
#import "SentrySamplingContext.h"
#import "SentrySwift.h"
#import "SentryTransactionContext.h"
#import <SentryOptionsInternal+Private.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Private

/**
 * @return A sample rate if the specified sampler callback was defined on @c SentryOptions and
 * returned a valid value, @c nil otherwise.
 */
NSNumber *_Nullable _sentry_samplerCallbackRate(SentryTracesSamplerCallback _Nullable callback,
    SentrySamplingContext *context, NSNumber *_Nullable defaultSampleRate)
{
    if (callback == nil) {
        return nil;
    }

    NSNumber *callbackRate = callback(context);
    if (!sentry_isValidSampleRate(callbackRate)) {
        return defaultSampleRate;
    }

    return callbackRate;
}

SentrySamplerDecision *
_sentry_calcSample(NSNumber *_Nullable rate)
{
    double random = [SentryDependencyContainer.sharedInstance.random nextNumber];
    SentrySampleDecision decision
        = random <= rate.doubleValue ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
    return [[SentrySamplerDecision alloc] initWithDecision:decision
                                             forSampleRate:rate
                                            withSampleRand:@(random)];
}

SentrySamplerDecision *
_sentry_calcSampleFromNumericalRate(NSNumber *_Nullable rate)
{
    if (rate == nil) {
        return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                 forSampleRate:nil
                                                withSampleRand:nil];
    }

    return _sentry_calcSample(rate);
}

#pragma mark - Public

SentrySamplerDecision *
sentry_sampleTrace(SentrySamplingContext *context, SentryOptions *_Nullable options)
{
    // check this transaction's sampling decision, if already decided
    if (context.transactionContext.sampled != kSentrySampleDecisionUndecided) {
        return
            [[SentrySamplerDecision alloc] initWithDecision:context.transactionContext.sampled
                                              forSampleRate:context.transactionContext.sampleRate
                                             withSampleRand:context.transactionContext.sampleRand];
    }

    NSNumber *callbackRate = _sentry_samplerCallbackRate(
        options.tracesSampler, context, SENTRY_DEFAULT_TRACES_SAMPLE_RATE);
    if (callbackRate != nil) {
        return _sentry_calcSample(callbackRate);
    }

    // check the _parent_ transaction's sampling decision, if any
    if (context.transactionContext.parentSampled != kSentrySampleDecisionUndecided) {
        return
            [[SentrySamplerDecision alloc] initWithDecision:context.transactionContext.parentSampled
                                              forSampleRate:context.transactionContext.sampleRate
                                             withSampleRand:context.transactionContext.sampleRand];
    }

    return _sentry_calcSampleFromNumericalRate(options.tracesSampleRate);
}

#if SENTRY_TARGET_PROFILING_SUPPORTED

SentrySamplerDecision *
sentry_sampleProfileSession(float sessionSampleRate)
{
    return _sentry_calcSampleFromNumericalRate(@(sessionSampleRate));
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_END
