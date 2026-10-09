#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryContinuousProfiler.h"

@class SentryProfiler;

@interface SentryContinuousProfiler ()

+ (void)stopTimerAndCleanup;
+ (nullable SentryProfiler *)profiler;
+ (void)transmitChunkEnvelope;

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
