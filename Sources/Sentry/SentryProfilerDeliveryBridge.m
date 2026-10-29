#import "SentryProfilerDeliveryBridge.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryEvent+Private.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilingSwiftHelpers.h"
#    import "SentrySwift.h"
#    import "SentryTraceProfiler.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransaction+Private.h"
#    if SENTRY_HAS_UIKIT
#        import "SentryAppStartMeasurement.h"
#    endif

void
sentry_finishProfiledTransaction(SentryHubInternal *hub, SentryProfilingDispatch dispatchAsync,
    SentryTransaction *transaction, BOOL isProfiling, BOOL isLaunchTrace,
    BOOL continuousTraceProfiling, NSDate *_Nullable traceStartTimestamp, uint64_t startSystemTime
#    if SENTRY_HAS_UIKIT
    ,
    SentryAppStartMeasurement *_Nullable appStartMeasurement
#    endif // SENTRY_HAS_UIKIT
)
{
    if ([SentryProfilerSDKAdapter.shared configuration].traceLaunchConfigured) {
        SENTRY_LOG_DEBUG(@"Stopping launch UI trace profile.");
        sentry_finishContinuousProfileForTrace();
        // The launch tracer is intentionally discarded by
        // SentryLaunchProfiling.stopAndDiscardLaunchProfileTracer. Other transactions finishing
        // during the launch profiling window (e.g., manual transactions or app start transactions)
        // must still be captured.
        if (!isLaunchTrace) {
            [hub captureTransaction:transaction withScope:hub.scope];
        }
        return;
    }

    if (isProfiling && continuousTraceProfiling) {
        SENTRY_LOG_DEBUG(@"Stopping tracking root span tracer with profilerReferenceId %@",
            sentry_stringFromSentryID(transaction.trace.profilerReferenceID));
        sentry_finishContinuousProfileForTrace();
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }

    if (!isProfiling) {
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }

    NSDate *startTimestamp;

#    if SENTRY_HAS_UIKIT
    if (appStartMeasurement != nil) {
        startTimestamp = appStartMeasurement.runtimeInitTimestamp;
    }
#    endif // SENTRY_HAS_UIKIT

    if (startTimestamp == nil) {
        startTimestamp = traceStartTimestamp;
    }
    if (!SENTRY_CASSERT_RETURN(startTimestamp != nil,
            @"A transaction with a profile should have a start timestamp already. We will "
            @"assign the current time but this will be incorrect.")) {
        startTimestamp = SentryProfilerSDKAdapter.shared.date;
    }

    // if we have an app start span, use its app start timestamp. otherwise use the tracer's
    // start system time as we currently do
    SENTRY_LOG_DEBUG(@"Tracer start time: %llu", startSystemTime);

    transaction.startSystemTime = startSystemTime;
#    if SENTRY_HAS_UIKIT
    if (appStartMeasurement != nil) {
        SENTRY_LOG_DEBUG(@"Assigning transaction start time as app start system time (%llu)",
            appStartMeasurement.runtimeInitSystemTimestamp);
        transaction.startSystemTime = appStartMeasurement.runtimeInitSystemTimestamp;
    }
#    endif // SENTRY_HAS_UIKIT

    [SentryTraceProfiler recordMetrics];
    transaction.endSystemTime = SentryProfilerSDKAdapter.shared.systemTime;

    SentryProfiler *_Nullable nullableProfiler
        = sentry_profilerForFinishedTracer(transaction.trace.profilerReferenceID);
    if (!nullableProfiler) {
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }
    SentryProfiler *_Nonnull profiler = SENTRY_UNWRAP_NULLABLE(SentryProfiler, nullableProfiler);

    // This code can run on the main thread, and the profile serialization can take a couple of
    // milliseconds. Therefore, we move this to a background thread to avoid potentially
    // blocking the main thread.
    dispatchAsync(^{
        NSDictionary<NSString *, id> *profilingData = [profiler.state copyProfilingData];

        SentryEnvelopeItem *_Nullable profileEnvelopeItem = sentry_traceProfileEnvelopeItem(
            hub, profiler, profilingData, transaction, startTimestamp);

        if (!profileEnvelopeItem) {
            [hub captureTransaction:transaction withScope:hub.scope];
        } else {
            [hub captureTransaction:transaction
                              withScope:hub.scope
                additionalEnvelopeItems:@[ SENTRY_UNWRAP_NULLABLE(
                                            SentryEnvelopeItem, profileEnvelopeItem) ]];
        }
    });
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
