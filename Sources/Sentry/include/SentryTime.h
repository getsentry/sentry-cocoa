#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCompiler.h"
#    import <stdint.h>

SENTRY_EXTERN_C_BEGIN

/**
 * Returns the absolute timestamp, which has no defined reference point or unit
 * as it is platform dependent.
 */
uint64_t getAbsoluteTime();

/**
 * Returns the duration in nanoseconds between two absolute timestamps.
 */
uint64_t getDurationNs(uint64_t startTimestamp, uint64_t endTimestamp);

SENTRY_EXTERN_C_END

#endif
