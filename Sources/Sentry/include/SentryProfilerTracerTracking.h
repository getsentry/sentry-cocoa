#import "SentryCompiler.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@class SentryProfiler;

@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryHub;
@class SentryTransaction;
@class SentryDispatchQueueWrapper;
@class SentryTracerConfiguration;
@class SentryId;
@class SentryAppStartMeasurement;
@class SentryTransactionContext;

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

void sentry_captureTransactionWithProfile(SentryHub *hub, SentryDispatchQueueWrapper *dispatchQueue,
    SentryTransaction *transaction, NSDate *startTimestamp);

SentryId *_Nullable startProfiler(SentryTracerConfiguration *configuration, SentryHub *hub,
    SentryTransactionContext *transactionContext);

void discardProfiler(SentryId *internalTraceID);

void stopProfilerDueToFinishedTransaction(SentryHub *hub, SentryDispatchQueueWrapper *dispatchQueue,
    SentryTransaction *transaction, SentryAppStartMeasurement *appStartMeasurement,
    BOOL isProfiling, NSDate *traceStartTimestamp, uint64_t startSystemTime);

/**
 * Associate the provided profiler and tracer so that profiling data may be retrieved by the tracer
 * when it is ready to transmit its envelope.
 */
void sentry_trackProfilerForTracer(SentryProfiler *profiler, SentryId *internalTraceId);

/**
 * For transactions that will be discarded, clean up the bookkeeping state associated with them to
 * reclaim the memory they're using.
 */
void sentry_discardProfilerForTracer(SentryId *internalTraceId);

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
