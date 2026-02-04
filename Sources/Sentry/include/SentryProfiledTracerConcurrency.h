#import "SentryCompiler.h"
#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import "SentrySampleDecision.h"
#import <Foundation/Foundation.h>

@class SentryProfiler;

@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryHubInternal;
@class SentryTransaction;
@class SentryDispatchQueueWrapper;
@class SentryTracerConfiguration;
@class SentryProfileOptions;
@class SentryId;
@class SentryTransactionContext;

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

/**
 * @Returns An ID to use as a unique, unchanging ID for the tracer that started the profiler. It's
 * different from the profiler's internal ID.
 */
SentryId *_Nullable sentry_startProfilerForTrace(SentryTracerConfiguration *configuration,
    SentryHubInternal *_Nullable hub, SentryTransactionContext *transactionContext);

/**
 * @note Only called for transaction-based profiling or continuous profiling V2 with trace lifecycle
 * option configured.
 * @param appStartRuntimeInitTimestamp The runtime init timestamp from app start measurement, or nil if not available.
 * @param appStartRuntimeInitSystemTimestamp The runtime init system timestamp from app start measurement, or 0 if not available.
 */
SENTRY_EXTERN void sentry_stopProfilerDueToFinishedTransaction(SentryHubInternal *hub,
    SentryDispatchQueueWrapper *dispatchQueue, SentryTransaction *transaction, BOOL isProfiling,
    NSDate *_Nullable traceStartTimestamp, uint64_t startSystemTime,
    NSDate *_Nullable appStartRuntimeInitTimestamp, uint64_t appStartRuntimeInitSystemTimestamp);

/**
 * Associate the provided profiler and tracer so that profiling data may be retrieved by the tracer
 * when it is ready to transmit its envelope.
 */
void sentry_trackTransactionProfilerForTrace(SentryProfiler *profiler, SentryId *internalTraceId);

/**
 * For transactions that will be discarded, clean up the bookkeeping state associated with them to
 * reclaim the memory they're using.
 */
void sentry_discardProfilerCorrelatedToTrace(SentryId *internalTraceId, SentryHubInternal *hub);

/**
 * Return the profiler instance associated with the tracer. If it was the last tracer for the
 * associated profiler, stop that profiler. Copy any recorded @c SentryScreenFrames data into the
 * profiler instance, and if this is the last profiler being tracked, reset the
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
