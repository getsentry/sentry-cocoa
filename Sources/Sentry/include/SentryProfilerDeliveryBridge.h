#import "SentryCompiler.h"
#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import "SentryProfilingDispatch.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryHubInternal;
@class SentryTransaction;
@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryProfiler;
@class SentryId;
@class SentryProfilingFrameMeasurements;
#    if SENTRY_HAS_UIKIT
@class SentryAppStartMeasurement;
#    endif

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

SENTRY_EXTERN void sentry_finishProfiledTransaction(
    SentryHubInternal *hub, SentryProfilingDispatch dispatchAsync, SentryTransaction *transaction,
    BOOL isProfiling, BOOL isLaunchTrace, BOOL continuousTraceProfiling,
    NSDate *_Nullable traceStartTimestamp, uint64_t startSystemTime
#    if SENTRY_HAS_UIKIT
    ,
    SentryAppStartMeasurement *_Nullable appStartMeasurement
#    endif
);

SENTRY_EXTERN SentryEnvelopeItem *_Nullable sentry_traceProfileEnvelopeItem(SentryHubInternal *hub,
    SentryProfiler *profiler, NSDictionary<NSString *, id> *profilingData,
    SentryTransaction *transaction, NSDate *startTimestamp);

SentryEnvelope *_Nullable sentry_continuousProfileChunkEnvelope(
    SentryId *profileID, NSDictionary *profileState, NSDictionary *metricProfilerState
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif // SENTRY_HAS_UIKIT
);

/** Alternative affordance for use by hybrid SDKs. */
NSMutableDictionary<NSString *, id> *_Nullable sentry_collectProfileDataHybridSDK(
    uint64_t startSystemTime, uint64_t endSystemTime, SentryId *traceId, SentryHubInternal *hub);

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
