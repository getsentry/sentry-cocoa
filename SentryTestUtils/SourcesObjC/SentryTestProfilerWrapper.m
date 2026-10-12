#import "SentryTestProfilerWrapper.h"

#if SWIFT_PACKAGE && !SDK_V10 && SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentrySwift.h"

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

#    if SENTRY_HAS_UIKIT
@implementation TestDelayedWrapper
- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(id)dateProvider
{
    return [super initWithKeepDelayedFramesDuration:keepDelayedFramesDuration
                                       dateProvider:(id<SentryCurrentDateProvider>)dateProvider];
}
@end
#    endif
#endif
