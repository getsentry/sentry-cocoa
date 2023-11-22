#import "SentryBaseObject.h"
#import "SentryTracer+Private.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryBaseObject

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
    [SentryTracer startLaunchProfile];
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
