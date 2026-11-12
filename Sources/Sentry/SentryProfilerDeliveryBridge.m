#import "SentryProfilerDeliveryBridge.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryDateUtils.h"
#    import "SentryDevice.h"
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
#    import "SentryScope+Private.h"
#    import "SentryScope+PrivateSwift.h"
#    import "SentrySwift.h"
#    import "SentryTraceProfiler.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransactionContext+Private.h"
#    if SENTRY_HAS_UIKIT
#        import "SentryAppStartMeasurement.h"
#    endif

static NSMutableDictionary<NSString *, id> *_Nullable _sentry_enrichedTraceProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages, SentryHubInternal *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif
)
{
    NSMutableDictionary<NSString *, id> *payload = sentry_serializedTraceProfileData(profileData,
        startSystemTime, endSystemTime, truncationReason, serializedMetrics, debugImages
#    if SENTRY_HAS_UIKIT
        ,
        gpuData
#    endif
    );
    if (payload == nil) {
        [hub.getClient recordLostEvent:SentryDataCategoryProfile
                                reason:SentryDiscardReasonEventProcessor];
        return nil;
    }

    payload[SENTRY_CONTEXT_OS_KEY] = @ {
        @"name" : sentry_getOSName(),
        @"version" : sentry_getOSVersion(),
        @"build_number" : sentry_getOSBuildNumber()
    };

    bool isEmulated = sentry_isSimulatorBuild();
    NSMutableDictionary *deviceDict = [[NSMutableDictionary alloc] initWithDictionary:@{
        @"architecture" : sentry_getCPUArchitecture(),
        @"is_emulator" : @(isEmulated),
        @"manufacturer" : @"Apple",
    }];
#    if !SDK_V10
    deviceDict[@"locale"] = NSLocale.currentLocale.localeIdentifier;
#    endif
    NSString *_Nullable deviceModel
        = isEmulated ? sentry_getSimulatorDeviceModel() : sentry_getDeviceModel();
    if (deviceModel != nil) {
        deviceDict[@"model"] = SENTRY_UNWRAP_NULLABLE(NSString, deviceModel);
    }
    payload[SENTRY_CONTEXT_DEVICE_KEY] = deviceDict;

    payload[@"profile_id"] = [[[SentryId alloc] init] sentryIdString];
    payload[@"environment"] = hub.scope.environmentString ?: hub.getClient.options.environment;
    payload[@"release"] = hub.getClient.options.releaseName;

    return payload;
}

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
    SentryTracer *trace = (SentryTracer *)transaction.trace;
    if ([SentryProfilerSDKAdapter.shared configuration].traceLaunchConfigured) {
        if (isProfiling) {
            SENTRY_LOG_DEBUG(@"Stopping launch UI trace profile.");
            sentry_finishContinuousProfileForTrace(trace.profilerReferenceID);
        }
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
            trace.profilerReferenceID.stringValue);
        sentry_finishContinuousProfileForTrace(trace.profilerReferenceID);
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

    SentryProfiler *_Nullable nullableProfiler
        = sentry_profilerForFinishedTracer(trace.profilerReferenceID);
    // Finishing a late tracer must not extend metrics from an aborted profiler.
    if (nullableProfiler != nil
        && nullableProfiler.truncationReason == SentryProfilerTruncationReasonNormal) {
        [nullableProfiler.metricProfiler recordMetrics];
    }
    transaction.endSystemTime = SentryProfilerSDKAdapter.shared.systemTime;
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
    SentryId *profileID, NSDictionary *profileState, NSDictionary *metricProfilerState,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages, SentryHubInternal *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif // SENTRY_HAS_UIKIT
)
{
    SentryId *chunkID = [[SentryId alloc] init];
    NSMutableDictionary<NSString *, id> *payload
        = sentry_serializedContinuousProfileChunk(profileState, metricProfilerState, debugImages
#    if SENTRY_HAS_UIKIT
            ,
            gpuData
#    endif // SENTRY_HAS_UIKIT
        );

    if (payload == nil) {
        SENTRY_LOG_DEBUG(@"Payload was empty, will not create a profiling envelope item.");
        return nil;
    }

    payload[@"chunk_id"] = [chunkID sentryIdString];
    payload[@"profiler_id"] = profileID.sentryIdString;
    payload[@"environment"] = hub.scope.environmentString ?: hub.getClient.options.environment;
    payload[@"release"] = hub.getClient.options.releaseName;
    payload[@"platform"] = SentryPlatformName;

    NSMutableDictionary *clientInfo = [NSMutableDictionary dictionary];
    clientInfo[@"name"] = SentryMeta.sdkName;
    clientInfo[@"version"] = SentryMeta.versionString;
    payload[@"client_sdk"] = clientInfo;

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
    NSMutableDictionary<NSString *, id> *payload = _sentry_enrichedTraceProfileData(
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
        @"trace_id" : ((SentryTracer *)transaction.trace).traceId.sentryIdString,
    }];
    NSNumber *_Nullable activeThreadId =
        [((SentryTracer *)transaction.trace).transactionContext sentry_threadInfo].threadId;
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
    SentryProfiler *profiler
        = sentry_profilerForFinishedTracer(sentry_profilingIdFromSentryId(traceId));
    if (!profiler) {
        return nil;
    }

    return _sentry_enrichedTraceProfileData([profiler.state copyProfilingData], startSystemTime,
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
