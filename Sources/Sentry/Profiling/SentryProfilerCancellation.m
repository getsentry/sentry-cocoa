#import "SentryProfilerCancellation.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryProfilerCancellation {
    dispatch_block_t _cancellation;
}

- (instancetype)initWithCancellation:(dispatch_block_t)cancellation
{
    if (self = [super init]) {
        _cancellation = [cancellation copy];
    }
    return self;
}

- (void)cancel
{
    _cancellation();
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
