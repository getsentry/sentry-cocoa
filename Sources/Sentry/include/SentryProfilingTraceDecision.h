#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

typedef NS_ENUM(NSUInteger, SentryProfilingTraceDecision) {
    SentryProfilingTraceDecisionNone,
    SentryProfilingTraceDecisionContinuous,
    SentryProfilingTraceDecisionTransaction,
};

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
