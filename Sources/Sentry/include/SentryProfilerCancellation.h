#import "SentryDefines.h"
#import "SentryProfilingCancellation.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfilerCancellation : NSObject <SentryProfilingCancellation>
- (instancetype)initWithCancellation:(dispatch_block_t)cancellation;
SENTRY_NO_INIT
@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
