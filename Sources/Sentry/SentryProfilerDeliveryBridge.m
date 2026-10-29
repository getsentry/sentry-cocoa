#import "SentryProfilerDeliveryBridge.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDateUtils.h"
#    import "SentryEvent+Private.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryProfilerSerialization+Private.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentryProfilingSwiftHelpers.h"
#    import "SentrySDK+Private.h"
#    import "SentrySwift.h"
#    import "SentryTraceProfiler.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransaction+Private.h"
#    import "SentryTransactionContext+Private.h"
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

#    pragma mark - Public

SentryEnvelope *_Nullable sentry_continuousProfileChunkEnvelope(
    SentryId *profileID, NSDictionary *profileState, NSDictionary *metricProfilerState
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif // SENTRY_HAS_UIKIT
)
{
    SentryId *chunkID = [[SentryId alloc] init];
    NSMutableDictionary<NSString *, id> *payload = sentry_serializedContinuousProfileChunk(
        profileID, chunkID, profileState, metricProfilerState,
        [SentryProfilerSDKAdapter.shared serializedDebugImages], SentrySDKInternal.currentHub
#    if SENTRY_HAS_UIKIT
        ,
        gpuData
#    endif // SENTRY_HAS_UIKIT
    );

    if (payload == nil) {
        SENTRY_LOG_DEBUG(@"Payload was empty, will not create a profiling envelope item.");
        return nil;
    }

    NSData *JSONData = [SentrySerializationSwift dataWithJSONObject:payload];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON.");
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Transmitting continuous profile chunk.");

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(SENTRY_UI_TEST_SUPPORT)
    // only write profile payloads to disk for UI tests
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] != nil) {
        SENTRY_LOG_DEBUG(
            @"Writing profile to test file (profile ID %@, chunk ID %@", profileID, chunkID);
        sentry_writeProfileFile(JSONData, true /*continuous*/);
    }
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(SENTRY_UI_TEST_SUPPORT)

    SentryEnvelopeItem *envelopeItem =
        [[SentryEnvelopeItem alloc] initWithType:SentryEnvelopeItemTypes.profileChunk
                                            data:JSONData
                                     addPlatform:YES];

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [[SentryEnvelope alloc] initWithId:chunkID singleItem:envelopeItem];
#    pragma clang diagnostic pop
}

SentryEnvelopeItem *_Nullable sentry_traceProfileEnvelopeItem(SentryHubInternal *hub,
    SentryProfiler *profiler, NSDictionary<NSString *, id> *profilingData,
    SentryTransaction *transaction, NSDate *startTimestamp)
{
    NSArray<NSDictionary<NSString *, id> *> *images =
        [SentryProfilerSDKAdapter.shared serializedDebugImages];
    NSMutableDictionary<NSString *, id> *payload = sentry_serializedTraceProfileData(
        profilingData, transaction.startSystemTime, transaction.endSystemTime,
        sentry_profilerTruncationReasonName(profiler.truncationReason),
        [profiler.metricProfiler serializeTraceProfileMetricsBetween:transaction.startSystemTime
                                                                 and:transaction.endSystemTime],
        images, hub
#    if SENTRY_HAS_UIKIT
        ,
        profiler.screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );

    if (payload == nil) {
        SENTRY_LOG_DEBUG(@"Payload was empty, will not create a profiling envelope item.");
        return nil;
    }

    payload[@"platform"] = SentryPlatformName;
    NSMutableDictionary *transactionDict = [[NSMutableDictionary alloc] initWithDictionary:@ {
        @"id" : transaction.eventId.sentryIdString,
        @"trace_id" : transaction.trace.traceId.sentryIdString,
    }];
    NSNumber *_Nullable activeThreadId =
        [transaction.trace.transactionContext sentry_threadInfo].threadId;
    if (activeThreadId != nil || [activeThreadId isEqual:@0]) {
        transactionDict[@"active_thread_id"] = activeThreadId;
    }
    if (transaction.transaction) {
        transactionDict[@"name"] = transaction.transaction;
    }
    payload[@"transaction"] = transactionDict;
    payload[@"timestamp"] = sentry_toIso8601String(startTimestamp);

    NSData *JSONData = [SentrySerializationSwift dataWithJSONObject:payload];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON.");
        return nil;
    }

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(SENTRY_UI_TEST_SUPPORT)
    // only write profile payloads to disk for UI tests
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] != nil) {
        sentry_writeProfileFile(JSONData, false /*continuous*/);
    }
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(SENTRY_UI_TEST_SUPPORT)

    return [[SentryEnvelopeItem alloc] initWithType:SentryEnvelopeItemTypes.profile
                                               data:JSONData
                                        addPlatform:NO];
}

NSMutableDictionary<NSString *, id> *_Nullable sentry_collectProfileDataHybridSDK(
    uint64_t startSystemTime, uint64_t endSystemTime, SentryId *traceId, SentryHubInternal *hub)
{
    SentryProfiler *profiler = sentry_profilerForFinishedTracer(traceId);
    if (!profiler) {
        return nil;
    }

    return sentry_serializedTraceProfileData([profiler.state copyProfilingData], startSystemTime,
        endSystemTime, sentry_profilerTruncationReasonName(profiler.truncationReason),
        [profiler.metricProfiler serializeTraceProfileMetricsBetween:startSystemTime
                                                                 and:endSystemTime],
        [SentryProfilerSDKAdapter.shared serializedDebugImages], hub
#    if SENTRY_HAS_UIKIT
        ,
        profiler.screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
