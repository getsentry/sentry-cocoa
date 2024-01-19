#import "SentryTracesSampler.h"
#import "SentryDependencyContainer.h"
#import "SentryOptions.h"
#import "SentryRandom.h"
#import "SentrySamplingContext.h"
#import "SentryTransactionContext.h"
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTracesSamplerDecision

- (instancetype)initWithDecision:(SentrySampleDecision)decision
                   forSampleRate:(nullable NSNumber *)sampleRate
{
    if (self = [super init]) {
        _decision = decision;
        _sampleRate = sampleRate;
    }
    return self;
}

@end

@implementation SentryTracesSampler {
    SentryOptions *_options;
}

- (instancetype)initWithOptions:(SentryOptions *)options random:(id<SentryRandom>)random
{
    if (self = [super init]) {
        _options = options;
        self.random = random;
    }
    return self;
}

- (instancetype)initWithOptions:(SentryOptions *)options
{
    return [self initWithOptions:options random:[SentryDependencyContainer sharedInstance].random];
}

- (SentryTracesSamplerDecision *)sample:(SentrySamplingContext *)context
{
    if (context.transactionContext.sampled != kSentrySampleDecisionUndecided) {
        return [[SentryTracesSamplerDecision alloc]
            initWithDecision:context.transactionContext.sampled
               forSampleRate:context.transactionContext.sampleRate];
    }

    if (_options.tracesSampler != nil) {
        NSNumber *callbackDecision = _options.tracesSampler(context);
        if (callbackDecision != nil) {
            if (![_options isValidTracesSampleRate:callbackDecision]) {
                callbackDecision = _options.defaultTracesSampleRate;
            }
        }
        if (callbackDecision != nil) {
            return [self calcSample:callbackDecision];
        }
    }

    if (context.transactionContext.parentSampled != kSentrySampleDecisionUndecided)
        return [[SentryTracesSamplerDecision alloc]
            initWithDecision:context.transactionContext.parentSampled
               forSampleRate:context.transactionContext.sampleRate];

    if (_options.tracesSampleRate != nil)
        return [self calcSample:_options.tracesSampleRate];

    return [[SentryTracesSamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                   forSampleRate:nil];
}

- (SentryTracesSamplerDecision *)calcSample:(NSNumber *)rate
{
    return [[self class] calcSample:rate random:self.random];
}

+ (SentryTracesSamplerDecision *)calcSample:(NSNumber *)rate random:(id<SentryRandom>)random
{
    double r = [random nextNumber];
    SentrySampleDecision decision
        = r <= rate.doubleValue ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
    return [[SentryTracesSamplerDecision alloc] initWithDecision:decision forSampleRate:rate];
}

@end

NS_ASSUME_NONNULL_END
