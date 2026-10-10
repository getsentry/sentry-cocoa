#import "SentryTestProfilerWrapper.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED || SENTRY_HAS_UIKIT
#    import "SentrySwift.h"
#endif

#if SENTRY_TARGET_PROFILING_SUPPORTED
void
sentry_test_sdkInitProfilerTasks(NSObject *options, SentryHubInternal *hub)
{
    sentry_sdkInitProfilerTasks((SentryOptions *)options, hub);
}

void
sentry_test_configureContinuousProfiling(NSObject *options)
{
    sentry_configureContinuousProfiling((SentryOptions *)options);
}

void
sentry_test_configureLaunchProfilingForNextLaunch(NSObject *options)
{
    sentry_configureLaunchProfilingForNextLaunch((SentryOptions *)options);
}

BOOL
sentry_test_willProfileNextLaunch(NSObject *options)
{
    return sentry_willProfileNextLaunch((SentryOptions *)options);
}

#endif

#if SENTRY_HAS_UIKIT
@implementation TestDelayedWrapper
- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(id)dateProvider
{
    return [super initWithKeepDelayedFramesDuration:keepDelayedFramesDuration
                                       dateProvider:(id<SentryCurrentDateProvider>)dateProvider];
}
@end
#endif
