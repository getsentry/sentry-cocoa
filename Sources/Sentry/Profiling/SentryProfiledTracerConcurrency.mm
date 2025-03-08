#import "SentryProfiledTracerConcurrency.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryContinuousProfiler.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfiler+Private.h"
#    import "SentrySwift.h"
#    include <mutex>

#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryEvent+Private.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryLog.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySwift.h"
#    import "SentryTraceProfiler.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransaction.h"

#    if SENTRY_HAS_UIKIT
#        import "SentryAppStartMeasurement.h"
#        import "SentryDependencyContainer.h"
#        import "SentryFramesTracker.h"
#        import "SentryScreenFrames.h"
#    endif // SENTRY_HAS_UIKIT

/**
 * a mapping of profilers to the number of tracers that started them that are still in-flight and
 * will need to query them for their profiling data when they finish. this helps resolve the
 * incongruity between the different timeout durations between tracers (500s) and profilers (30s),
 * where a transaction may start a profiler that then times out, and then a new transaction starts a
 * new profiler, and we must keep the aborted one around until its associated transaction finishes.
 */
static NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
    /* number of in-flight tracers */ NSNumber *> *_gProfilersToTracers;

/** provided for fast access to a profiler given a tracer */
static NSMutableDictionary</* SentryTracer.internalTraceId */ NSString *, SentryProfiler *>
    *_gTracersToProfilers;

static unsigned int _gInFlightRootSpans = 0;

namespace {

std::mutex _gStateLock;

/**
 * Remove a profiler from tracking given the id of the tracer it's associated with.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpProfiler(SentryProfiler *profiler, NSString *tracerKey)
{
    const auto profilerKey = profiler.profilerId.sentryIdString;
    [_gTracersToProfilers removeObjectForKey:tracerKey];
    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue - 1);
    if ([_gProfilersToTracers[profilerKey] unsignedIntValue] == 0) {
        [_gProfilersToTracers removeObjectForKey:profilerKey];
        if ([profiler isRunning]) {
            [profiler stopForReason:SentryProfilerTruncationReasonNormal];
        }
    }
}

/**
 * Decrement number of root spans in flight and stop continuous profiler if there are none left.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpProfilerContinuous()
{
    if (SENTRY_CASSERT_RETURN(_gInFlightRootSpans > 0,
            @"Attempted to decrement count of root spans to less than zero.")) {
        _gInFlightRootSpans -= 0;
    }

    if (_gInFlightRootSpans == 0) {
        [SentryContinuousProfiler stop];
    }
}

void
sentry_trackRootSpanForContinuousProfiler()
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if (_gInFlightRootSpans == 0) {
        [SentryContinuousProfiler start];
    }

    _gInFlightRootSpans += 1;
}

void
sentry_stopTrackingRootSpanForContinuousProfiler()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    _unsafe_cleanUpProfilerContinuous();
}

} // namespace

void
sentry_trackProfilerForTracer(SentryProfiler *profiler, SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    const auto profilerKey = profiler.profilerId.sentryIdString;
    const auto tracerKey = internalTraceId.sentryIdString;

    SENTRY_LOG_DEBUG(
        @"Tracking relationship between profiler id %@ and tracer id %@", profilerKey, tracerKey);

    SENTRY_CASSERT((_gProfilersToTracers == nil && _gTracersToProfilers == nil)
            || (_gProfilersToTracers != nil && _gTracersToProfilers != nil),
        @"Both structures must be initialized simultaneously.");

    if (_gProfilersToTracers == nil) {
        _gProfilersToTracers = [NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
            /* number of in-flight tracers */ NSNumber *>
            dictionary];
        _gTracersToProfilers =
            [NSMutableDictionary</* SentryTracer.internalTraceId */ NSString *, SentryProfiler *>
                dictionary];
    }

    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue + 1);
    _gTracersToProfilers[tracerKey] = profiler;
}

void
sentry_discardProfiler(SentryId *internalTraceId, SentryHub *hub)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if ([hub.getClient.options isContinuousProfilingEnabled]) {
        _unsafe_cleanUpProfilerContinuous();
    } else {
        if (internalTraceId == nil) {
            return;
        }

        SENTRY_CASSERT(_gTracersToProfilers != nil && _gProfilersToTracers != nil,
            @"Structures should have already been initialized by the time they are being queried");

        const auto tracerKey = internalTraceId.sentryIdString;
        const auto profiler = _gTracersToProfilers[tracerKey];

        if (profiler == nil) {
            return;
        }

        _unsafe_cleanUpProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
        if (_gProfilersToTracers.count == 0) {
            [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
        }
#    endif // SENTRY_HAS_UIKIT
    }
}

SentryProfiler *_Nullable sentry_profilerForFinishedTracer(SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    SENTRY_CASSERT(_gTracersToProfilers != nil && _gProfilersToTracers != nil,
        @"Structures should have already been initialized by the time they are being queried");

    const auto tracerKey = internalTraceId.sentryIdString;
    const auto profiler = _gTracersToProfilers[tracerKey];

    if (!SENTRY_CASSERT_RETURN(profiler != nil,
            @"Expected a profiler to be associated with tracer id %@.", tracerKey)) {
        return nil;
    }

    _unsafe_cleanUpProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
    profiler.screenFrameData =
        [SentryDependencyContainer.sharedInstance.framesTracker.currentFrames copy];
    SENTRY_LOG_DEBUG(
        @"Grabbing copy of frames tracker screen frames data to attach to profiler: %@.",
        profiler.screenFrameData);
    if (_gProfilersToTracers.count == 0) {
        [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT

    return profiler;
}

void
sentry_stopProfilerDueToFinishedTransaction(
    SentryHub *hub, SentryDispatchQueueWrapper *dispatchQueue, SentryTransaction *transaction,
    BOOL isProfiling, NSDate *traceStartTimestamp, uint64_t startSystemTime
#    if SENTRY_HAS_UIKIT
    ,
    SentryAppStartMeasurement *appStartMeasurement
#    endif // SENTRY_HAS_UIKIT
)
{
    if ([hub.getClient.options isContinuousProfilingEnabled]) {
        sentry_stopTrackingRootSpanForContinuousProfiler();
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
        startTimestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
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
    transaction.endSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;

    const auto profiler = sentry_profilerForFinishedTracer(transaction.trace.profilerReferenceID);
    if (!profiler) {
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }

    // This code can run on the main thread, and the profile serialization can take a couple of
    // milliseconds. Therefore, we move this to a background thread to avoid potentially
    // blocking the main thread.
    [dispatchQueue dispatchAsyncWithBlock:^{
        const auto profilingData = [profiler.state copyProfilingData];

        const auto profileEnvelopeItem = sentry_traceProfileEnvelopeItem(
            hub, profiler, profilingData, transaction, startTimestamp);

        if (!profileEnvelopeItem) {
            [hub captureTransaction:transaction withScope:hub.scope];
        } else {
            [hub captureTransaction:transaction
                              withScope:hub.scope
                additionalEnvelopeItems:@[ profileEnvelopeItem ]];
        }
    }];
}

SentryId *_Nullable sentry_startProfiler(SentryTracerConfiguration *configuration, SentryHub *hub,
    SentryTransactionContext *transactionContext)
{
    if ([hub.getClient.options isContinuousProfilingEnabled]) {
        sentry_trackRootSpanForContinuousProfiler();
        return [[SentryId alloc] init];
    } else {
        BOOL profileShouldBeSampled
            = configuration.profilesSamplerDecision.decision == kSentrySampleDecisionYes;
        BOOL isContinuousProfiling = [hub.client.options isContinuousProfilingEnabled];
        BOOL shouldStartNormalTraceProfile = !isContinuousProfiling && profileShouldBeSampled;
        if (sentry_isTracingAppLaunch || shouldStartNormalTraceProfile) {
            SentryId *internalID = [[SentryId alloc] init];
            if ([SentryTraceProfiler startWithTracer:internalID]) {
                SENTRY_LOG_DEBUG(@"Started profiler for trace %@ with internal id %@",
                    transactionContext.traceId.sentryIdString, internalID.sentryIdString);
                return internalID;
            }
        }
        return nil;
    }
}

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
void
sentry_resetConcurrencyTracking()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    [_gTracersToProfilers removeAllObjects];
    [_gProfilersToTracers removeAllObjects];
}

NSUInteger
sentry_currentProfiledTracers()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    return [_gTracersToProfilers count];
}
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
