#import "Wrappers/SentryProfiler+PrivateWrapper.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
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
#endif
