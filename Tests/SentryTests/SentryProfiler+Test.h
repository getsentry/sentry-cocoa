#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface
SentryProfiler ()

+ (SentryProfiler *)getCurrentProfiler;

#    if SENTRY_PROFILING_MODE_LEGACY
+ (void)resetConcurrencyTracking;
+ (NSUInteger)currentProfiledTracers;
#    endif // SENTRY_PROFILING_MODE_LEGACY

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
