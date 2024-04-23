#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryProfiler+Private.h"

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryProfiler ()

+ (SentryProfiler *)getCurrentProfiler;

+ (void)sentry_resetConcurrencyTracking;

+ (NSUInteger)sentry_currentProfiledTracers;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
