#import "SentrySampling.h"
#import "SentryDependencyContainer.h"
#import "SentryInternalDefines.h"
#import "SentryOptions.h"
#import "SentryRandom.h"
#import "SentrySampleDecision.h"
#import "SentrySamplerDecision.h"
#import "SentrySamplingContext.h"
#import "SentryTransactionContext.h"
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Private

/**
 * @return A sample rate if the specified sampler callback was defined on @c SentryOptions and
 * returned a valid value, @c nil otherwise.
 */
NSNumber *_Nullable samplerCallbackRate(SentryTracesSamplerCallback _Nullable callback,
    SentrySamplingContext *context, NSNumber *defaultSampleRate)
{
    if (callback == nil) {
        return nil;
    }

    NSNumber *callbackRate = callback(context);
    if (!isValidSampleRate(callbackRate)) {
        return defaultSampleRate;
    }

    return callbackRate;
}

SentrySamplerDecision *
calcSample(NSNumber *rate)
{
    double random = [SentryDependencyContainer.sharedInstance.random nextNumber];
    SentrySampleDecision decision
        = random <= rate.doubleValue ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
    return [[SentrySamplerDecision alloc] initWithDecision:decision forSampleRate:rate];
}

SentrySamplerDecision *
calcSampleFromNumericalRate(NSNumber *rate)
{
    if (rate == nil) {
        return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                 forSampleRate:nil];
    }

    return calcSample(rate);
}

#pragma mark - Public

SentrySamplerDecision *
sampleTrace(SentrySamplingContext *context, SentryOptions *options)
{
    // check this transaction's sampling decision, if already decided
    if (context.transactionContext.sampled != kSentrySampleDecisionUndecided) {
        return
            [[SentrySamplerDecision alloc] initWithDecision:context.transactionContext.sampled
                                              forSampleRate:context.transactionContext.sampleRate];
    }

    NSNumber *callbackRate
        = samplerCallbackRate(options.tracesSampler, context, SENTRY_DEFAULT_TRACES_SAMPLE_RATE);
    if (callbackRate != nil) {
        return calcSample(callbackRate);
    }

    // check the _parent_ transaction's sampling decision, if any
    if (context.transactionContext.parentSampled != kSentrySampleDecisionUndecided) {
        return
            [[SentrySamplerDecision alloc] initWithDecision:context.transactionContext.parentSampled
                                              forSampleRate:context.transactionContext.sampleRate];
    }

    return calcSampleFromNumericalRate(options.tracesSampleRate);
}

#if SENTRY_TARGET_PROFILING_SUPPORTED

SentrySamplerDecision *
sampleProfile(SentrySamplingContext *context, SentrySamplerDecision *tracesSamplerDecision,
    SentryOptions *options)
{
    // Profiles are always undersampled with respect to traces. If the trace is not sampled,
    // the profile will not be either. If the trace is sampled, we can proceed to checking
    // whether the associated profile should be sampled.
    if (tracesSamplerDecision.decision != kSentrySampleDecisionYes) {
        return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                 forSampleRate:nil];
    }

    // Backward compatibility for clients that are still using the enableProfiling option.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (options.enableProfiling) {
        return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                                 forSampleRate:@1.0];
    }
#    pragma clang diagnostic pop

    NSNumber *callbackRate = samplerCallbackRate(
        options.profilesSampler, context, SENTRY_DEFAULT_PROFILES_SAMPLE_RATE);
    if (callbackRate != nil) {
        return calcSample(callbackRate);
    }

    return calcSampleFromNumericalRate(options.profilesSampleRate);
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_END
