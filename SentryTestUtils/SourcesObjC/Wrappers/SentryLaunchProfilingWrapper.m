#import "Wrappers/SentryLaunchProfilingWrapper.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentrySwift.h"

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
