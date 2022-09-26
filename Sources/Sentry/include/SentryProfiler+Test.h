#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
@interface
SentryProfiler (SentryTest)

+ (void)timeoutAbort;

@end
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
