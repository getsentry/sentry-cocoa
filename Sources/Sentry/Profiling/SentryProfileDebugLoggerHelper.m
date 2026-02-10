#if defined(DEBUG)

#    import "SentryProfileLoggerHelper.h"
#    import "SentrySwift.h"

@implementation SentryProfileLoggerHelper

+ (uint64_t)getAbsoluteTimeStampFromSample:(SentrySample *)sample
{
    return sample.absoluteTimestamp;
}

@end

#endif
