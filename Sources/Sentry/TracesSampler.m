#import "TracesSampler.h"
#import "SentryOptions.h"
#import "SentrySamplingContext.h"
#import "SentryTransactionContext.h"

@implementation TracesSampler {
    SentryOptions *_options;
}

- (instancetype)initWithOptions:(SentryOptions *)options
{
    if (self = [super init]) {
        _options = options;
        srand48(time(0));
    }
    return self;
}

- (SentrySampleDecision)sample:(SentrySamplingContext *)context
{
    if (context.transactionContext.sampled != kSentrySampleDecisionUndecided)
        return context.transactionContext.sampled;

    if (_options.tracesSampler != nil) {
        NSNumber *callbackDecision = _options.tracesSampler(context);
        if (callbackDecision != nil)
            return [self calcSample:callbackDecision.doubleValue];
    }

    if (context.transactionContext.parentSampled != kSentrySampleDecisionUndecided)
        return context.transactionContext.parentSampled;

    if (_options.tracesSampleRate != nil)
        return [self calcSample:_options.tracesSampleRate.doubleValue];

    return kSentrySampleDecisionNo;
}

- (SentrySampleDecision)calcSample:(double)rate
{
    double r = drand48();
    if (self.definedRandom != nil)
        r = self.definedRandom.doubleValue;

    return rate < r ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
}

@end
