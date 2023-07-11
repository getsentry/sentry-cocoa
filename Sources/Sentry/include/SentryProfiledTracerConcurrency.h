#import "SentryCompiler.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@class SentryProfiler;
@class SentryTracer;

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

/**
 * Associate the provided profiler and tracer so that profiling data may be retrieved by the tracer
 * when it is ready to transmit its envelope.
 */
void trackProfilerForTracer(SentryProfiler *profiler, SentryTracer *tracer);

/**
 * Stop tracking the tracer with the specified ID. If it was the last tracer for the associated
 * profiler, stop that profiler. Copy any recorded @c SentryScreenFrames data into the profiler
 * instance, and if this is the last profiler being tracked, reset the @c SentryFramesTracker data.
 * @returns the associated profiler.
 */
SentryProfiler *_Nullable profilerForFinishedTracer(SentryTracer *tracer);

#    if defined(TEST) || defined(TESTCI)
void resetConcurrencyTracking(void);
#    endif // defined(TEST) || defined(TESTCI)

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
