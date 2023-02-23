#import "SentryTracerConcurrency.h"
#import "SentryId.h"
#import "SentryLog.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

static NSMutableSet<NSString *> *_gInFlightTraceIDs;

void
trackTracerWithID(SentryId *traceID)
{
    @synchronized(_gInFlightTraceIDs) {
        if (_gInFlightTraceIDs == nil) {
            _gInFlightTraceIDs = [NSMutableSet<NSString *> set];
        }
        const auto idString = traceID.sentryIdString;
        SENTRY_LOG_DEBUG(@"Adding tracer id %@", idString);
        [_gInFlightTraceIDs addObject:idString];
    }
}

void
stopTrackingTracerWithID(SentryId *traceID, SentryConcurrentTransactionCleanupBlock cleanup)
{
    @synchronized(_gInFlightTraceIDs) {
        const auto idString = traceID.sentryIdString;
        SENTRY_LOG_DEBUG(@"Removing trace id %@", idString);
        [_gInFlightTraceIDs removeObject:idString];
        if (_gInFlightTraceIDs.count == 0) {
            SENTRY_LOG_DEBUG(@"Last in flight tracer completed, performing cleanup.");
            cleanup();
        } else {
            SENTRY_LOG_DEBUG(@"Waiting on %lu other tracers to complete: %@.",
                _gInFlightTraceIDs.count, _gInFlightTraceIDs);
        }
    }
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
