#import "SentryTracerConcurrency.h"
#import "SentryId.h"
#import "SentryLog.h"

static NSMutableArray<SentryId *> *_gInFlightTraceIDs;

void
trackTracerWithID(SentryId *traceID)
{
    @synchronized(_gInFlightTraceIDs) {
        if (_gInFlightTraceIDs == nil) {
            _gInFlightTraceIDs = [NSMutableArray<SentryId *> array];
        }
        SENTRY_LOG_DEBUG(@"Adding tracer id %@", traceID.sentryIdString);
        [_gInFlightTraceIDs addObject:traceID];
    }
}

void
stopTrackingTracerWithID(SentryId *traceID, SentryConcurrentTransactionCleanupBlock cleanup)
{
    @synchronized(_gInFlightTraceIDs) {
        SENTRY_LOG_DEBUG(@"Removing trace id %@", traceID.sentryIdString);
        [_gInFlightTraceIDs removeObject:traceID];
        if (_gInFlightTraceIDs.count == 0) {
            SENTRY_LOG_DEBUG(@"Last in flight tracer completed, performing cleanup.");
            cleanup();
        } else {
            SENTRY_LOG_DEBUG(@"Waiting on %lu other tracers to complete: %@.",
                _gInFlightTraceIDs.count, _gInFlightTraceIDs);
        }
    }
}
