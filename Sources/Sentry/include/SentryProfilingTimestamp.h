#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

typedef struct {
    uint64_t systemTime;
    NSTimeInterval dateInterval;
} SentryProfilingTimestamp;

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
