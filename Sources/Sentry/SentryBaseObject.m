#import "SentryBaseObject.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryBaseObject

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
