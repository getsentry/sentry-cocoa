#import "SentryProfilesSampler.h"
#import "SentryDependencyContainer.h"
#import "SentryOptions+Private.h"
#import "SentryTracesSampler.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryProfilesSamplerDecision

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

@implementation SentryProfilesSampler {
    SentryOptions *_options;
    SentryTracesSamplerDecision *_tracesSamplerDecision;
}

- (instancetype)initWithOptions:(SentryOptions *)options random:(id<SentryRandom>)random tracesSamplerDecision:(SentryTracesSamplerDecision *)tracesSamplerDecision
{
    if (self = [super init]) {
        _options = options;
        _tracesSamplerDecision = tracesSamplerDecision;
        self.random = random;
    }
    return self;
}

- (instancetype)initWithOptions:(SentryOptions *)options tracesSamplerDecision:(SentryTracesSamplerDecision *)tracesSamplerDecision
{
    return [self initWithOptions:options random:[SentryDependencyContainer sharedInstance].random tracesSamplerDecision:tracesSamplerDecision];
}

- (SentryProfilesSamplerDecision *)sample:(__unused SentrySamplingContext *)context
{
    // Profiles are always undersampled with respect to traces. If the trace is not sampled,
    // the profile will not be either. If the trace is sampled, we can proceed to checking
    // whether the associated profile should be sampled.
    if (_tracesSamplerDecision.decision == kSentrySampleDecisionYes) {
        if (_options.profilesSampler != nil) {
            NSNumber *callbackDecision = _options.profilesSampler(context);
            if (callbackDecision != nil) {
                if (![_options isValidProfilesSampleRate:callbackDecision]) {
                    callbackDecision = _options.defaultProfilesSampleRate;
                }
            }
            if (callbackDecision != nil) {
                return [self calcSample:callbackDecision.doubleValue];
            }
        }
        
        if (_options.profilesSampleRate != nil) {
            return [self calcSample:_options.profilesSampleRate.doubleValue];
        }
    }
    
    return [[SentryProfilesSamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                     forSampleRate:nil];
}

- (SentryProfilesSamplerDecision *)calcSample:(double)rate
{
    double r = [self.random nextNumber];
    SentrySampleDecision decision = r <= rate ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
    return [[SentryProfilesSamplerDecision alloc] initWithDecision:decision
                                                   forSampleRate:[NSNumber numberWithDouble:rate]];
}

@end

NS_ASSUME_NONNULL_END
