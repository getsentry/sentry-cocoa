#import "SentryProfileDebugLoggerHelper.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED && defined(DEBUG)

#    import "SentrySwift.h"

@implementation SentryProfileDebugLoggerHelper

+ (uint64_t)getAbsoluteTimeStampFromSample:(SentrySample *)sample
{
    return sample.absoluteTimestamp;
}

@end

#endif
