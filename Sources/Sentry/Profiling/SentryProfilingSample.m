#import "SentryProfilingSample.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryProfilingSample

- (instancetype)init
{
    if (self = [super init]) {
        _stackIndex = @0;
    }
    return self;
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
