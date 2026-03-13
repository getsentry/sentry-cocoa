#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryProfilerState.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Creates a profiler sample from a stack of frame indices and appends the stack to state if new.
 * Used so that SentrySample (Swift) is only referenced from Objective-C, not from Objective-C++.
 */
#    if defined(__cplusplus)
extern "C" {
#    endif
SentrySample *sentry_profilerSampleWithStack(NSArray<NSNumber *> *stack, uint64_t absoluteTimestamp,
    NSTimeInterval absoluteNSDateInterval, uint64_t threadID, SentryProfilerMutableState *state);
#    if defined(__cplusplus)
}
#    endif

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
