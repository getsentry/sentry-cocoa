#import "SentryCompiler.h"
#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import "SentryProfilingTraceDecision.h"
#import <Foundation/Foundation.h>

@class SentryProfiler;

@class SentryId;
@class SentryTransactionContext;

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

/**
 * @Returns An ID to use as a unique, unchanging ID for the tracer that started the profiler. It's
 * different from the profiler's internal ID.
 */
SentryId *_Nullable sentry_startProfilerForTrace(
    SentryProfilingTraceDecision decision, SentryTransactionContext *transactionContext);

/**
 * Associate the provided profiler and tracer so that profiling data may be retrieved by the tracer
 * when it is ready to transmit its envelope.
 */
void sentry_trackTransactionProfilerForTrace(SentryProfiler *profiler, SentryId *internalTraceId);

SENTRY_EXTERN void sentry_finishContinuousProfileForTrace(void);

/**
 * For transactions that will be discarded, clean up the bookkeeping state associated with them to
 * reclaim the memory they're using.
 */
void sentry_discardProfilerCorrelatedToTrace(SentryId *internalTraceId);

/**
 * Return the profiler instance associated with the tracer. If it was the last tracer for the
 * associated profiler, stop that profiler. Copy any recorded @c SentryProfilingFrameMeasurements
 * data into the profiler instance, and if this is the last profiler being tracked, reset the
 * @c SentryFramesTracker data.
 */
SentryProfiler *_Nullable sentry_profilerForFinishedTracer(SentryId *internalTraceId);

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
void sentry_resetConcurrencyTracking(void);
NSUInteger sentry_currentProfiledTracers(void);
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
