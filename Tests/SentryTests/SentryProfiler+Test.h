#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryProfiler+Private.h"

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryProfiler ()

+ (SentryProfiler *)getCurrentProfiler;

/**
 * This just calls through to SentryProfiledTracerConcurrency.sentry_resetConcurrencyTracking(). we
 * have to do this through SentryTracer because SentryProfiledTracerConcurrency.h cannot be included
 * in test targets via ObjC bridging headers because it contains C++.
 */
+ (void)resetConcurrencyTracking;

/**
 * This just calls through to SentryProfiledTracerConcurrency.sentry_currentProfiledTracers(). we
 * have to do this through SentryTracer because SentryProfiledTracerConcurrency.h cannot be included
 * in test targets via ObjC bridging headers because it contains C++.
 */
+ (NSUInteger)currentProfiledTracers;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
