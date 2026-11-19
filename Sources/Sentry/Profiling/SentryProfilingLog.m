#import "SentryProfilingLog.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryProfilingLog

static __weak id<SentryProfilingLogger> _logger;

+ (id<SentryProfilingLogger>)logger
{
    @synchronized(self) {
        return _logger;
    }
}

+ (void)setLogger:(id<SentryProfilingLogger>)logger
{
    @synchronized(self) {
        _logger = logger;
    }
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
