#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

typedef struct {
    BOOL launchProfileCorrelatedToTraces;
    BOOL traceLaunchConfigured;
} SentryProfilingConfiguration;

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
