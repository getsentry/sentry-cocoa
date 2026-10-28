#import "SentryProfileConfiguration.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentrySwift.h"

/**
 * The current configuration the profiler operates under for this session. Set when a launch profile
 * runs, and then is updated on SDK start.
 */
static SentryProfileConfiguration *_Nullable sentry_profileConfiguration;

static NSObject *
sentry_profileConfigurationLock(void)
{
    static NSObject *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ lock = [[NSObject alloc] init]; });
    return lock;
}

SentryProfileConfiguration *_Nullable sentry_getProfileConfiguration(void)
{
    @synchronized(sentry_profileConfigurationLock()) {
        return sentry_profileConfiguration;
    }
}

void
sentry_setProfileConfiguration(SentryProfileConfiguration *_Nullable configuration)
{
    @synchronized(sentry_profileConfigurationLock()) {
        sentry_profileConfiguration = configuration;
    }
}

void
sentry_reevaluateSessionSampleRate(void)
{
    SentryProfileConfiguration *configuration = sentry_getProfileConfiguration();
    [configuration reevaluateSessionSampleRate];
}

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
{
    if (!(self = [super init])) {
        return nil;
    }

    _waitForFullDisplay = shouldWaitForFullDisplay;
    _isProfilingThisLaunch = YES;
    return self;
}

- (instancetype)initContinuousProfilingV2WaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                                               samplerDecision:(SENTRY_SWIFT_MIGRATION_ID(
                                                                   SentrySamplerDecision))decision
                                                profileOptions:(SENTRY_SWIFT_MIGRATION_ID(
                                                                   SentryProfileOptions))options
{
    if (!(self = [self initWaitingForFullDisplay:shouldWaitForFullDisplay])) {
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
    self.profilerSessionSampleDecision =
        [SentrySampling sampleProfileSession:self.profileOptions.sessionSampleRate];
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
