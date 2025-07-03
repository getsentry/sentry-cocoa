#import "SentryLaunchProfileConfiguration.h"
#import "SentrySampling.h"
#import "SentrySwift.h"

@interface SentryLaunchProfileConfiguration ()

@property (assign, nonatomic, readwrite) BOOL isContinuousV1;
@property (assign, nonatomic, readwrite) BOOL waitForFullDisplay;
@property (strong, nonatomic, nullable, readwrite)
    SentrySamplerDecision *profilerSessionSampleDecision;
@property (strong, nonatomic, nullable, readwrite) SentryProfileOptions *profileOptions;

@end

@implementation SentryLaunchProfileConfiguration

- (instancetype)initWaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                             continuousV1:(BOOL)continuousV1
{
    if (!(self = [super init])) {
        return nil;
    }

    self.waitForFullDisplay = shouldWaitForFullDisplay;
    self.isContinuousV1 = continuousV1;
    return self;
}

- (instancetype)initContinuousProfilingV2WaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                                               samplerDecision:(SentrySamplerDecision *)decision
                                                profileOptions:(SentryProfileOptions *)options
{
    if (!(self = [self initWaitingForFullDisplay:shouldWaitForFullDisplay continuousV1:NO])) {
        return nil;
    }

    self.profileOptions = options;
    self.profilerSessionSampleDecision = decision;
    return self;
}

- (void)reevaluateSessionSampleRate
{
    self.profilerSessionSampleDecision
        = sentry_sampleProfileSession(self.profileOptions.sessionSampleRate);
}

@end
