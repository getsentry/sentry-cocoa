#import "SentryCaptureTransactionWithProfile.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDispatchQueueWrapper.h"
#    import "SentryHub+Private.h"
#    import "SentryLog.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentrySwift.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransaction.h"

NS_ASSUME_NONNULL_BEGIN

void
sentry_captureTransactionWithProfile(SentryHub *hub, SentryDispatchQueueWrapper *dispatchQueue,
    SentryTransaction *transaction, NSDate *startTimestamp)
{
    const auto profiler = sentry_profilerForFinishedTracer(transaction.trace.internalID);
    if (!profiler) {
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }

    // This code can run on the main thread, and the profile serialization can take a couple of
    // milliseconds. Therefore, we move this to a background thread to avoid potentially blocking
    // the main thread.
    [dispatchQueue dispatchAsyncWithBlock:^{
        const auto profilingData = [profiler.state copyProfilingData];

        const auto profileEnvelopeItem = sentry_traceProfileEnvelopeItem(
            hub, profiler, profilingData, transaction, startTimestamp);

        if (!profileEnvelopeItem) {
            [hub captureTransaction:transaction withScope:hub.scope];
            return;
        }

        [hub captureTransaction:transaction
                          withScope:hub.scope
            additionalEnvelopeItems:@[ profileEnvelopeItem ]];
    }];
}

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
