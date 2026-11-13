#import "SentryProfileDebugLoggerHelper.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED && defined(DEBUG)

@implementation SentryProfileDebugLoggerHelper

+ (uint64_t)getAbsoluteTimeStampFromSample:(SentryProfilingSample *)sample
{
    return sample.absoluteTimestamp;
}

@end

#endif
