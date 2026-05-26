#import "SentryProfileConfiguration.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentrySampling.h"
#    import "SentrySwift.h"

@interface SentryProfileConfiguration ()
@property (strong, nonatomic, nullable, readwrite)
    SentrySamplerDecision *profilerSessionSampleDecision;
@end

@implementation SentryProfileConfiguration

@synthesize profilerSessionSampleDecision = _profilerSessionSampleDecision;

- (instancetype)initWithProfileOptions:(SentryProfileOptions *)options
{
    if (!(self = [super init])) {
        return nil;
    }

    _profileOptions = options;
    return self;
}

- (instancetype)initWaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                             continuousV1:(BOOL)continuousV1
{
    if (!(self = [super init])) {
        return nil;
    }

    _waitForFullDisplay = shouldWaitForFullDisplay;
    _isContinuousV1 = continuousV1;
    _isProfilingThisLaunch = YES;
    return self;
}

- (instancetype)initContinuousProfilingV2WaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                                               samplerDecision:(SentrySamplerDecision *)decision
                                                profileOptions:(SentryProfileOptions *)options
{
    if (!(self = [self initWaitingForFullDisplay:shouldWaitForFullDisplay continuousV1:NO])) {
        return nil;
    }

    _profileOptions = options;
    _profilerSessionSampleDecision = decision;
    _isProfilingThisLaunch = YES;
    return self;
}

- (SentrySamplerDecision *_Nullable)profilerSessionSampleDecision
{
    @synchronized(self) {
        return _profilerSessionSampleDecision;
    }
}

- (void)setProfilerSessionSampleDecision:(SentrySamplerDecision *_Nullable)decision
{
    @synchronized(self) {
        _profilerSessionSampleDecision = decision;
    }
}

- (void)reevaluateSessionSampleRate
{
    self.profilerSessionSampleDecision
        = sentry_sampleProfileSession(self.profileOptions.sessionSampleRate);
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
