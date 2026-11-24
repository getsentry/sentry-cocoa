#import "SentryTestProfilerWrapper.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED || SENTRY_HAS_UIKIT
#    import "SentrySwift.h"
#endif

#if SENTRY_TARGET_PROFILING_SUPPORTED
@interface SentryTestUnavailableEnrichmentProfilerBackend : SentryDefaultProfilerSDKBackend
@end

@implementation SentryTestUnavailableEnrichmentProfilerBackend
#    if SENTRY_HAS_UIKIT
- (SentryProfilingFrameMeasurements *_Nullable)copyFrameMeasurements
{
    return nil;
}
#    endif
@end

id<SentryProfilerSDKBackend>
sentry_test_createProfilerBackendWithoutEnrichment(void)
{
    return [[SentryTestUnavailableEnrichmentProfilerBackend alloc] init];
}

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
