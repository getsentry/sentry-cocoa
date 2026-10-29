#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import "SentryProfiler+Private.h"

@class SentryHubInternal;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeySlowFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrameRates;

SENTRY_EXTERN NSString *sentry_profilerTruncationReasonName(SentryProfilerTruncationReason reason);

/**
 * An intermediate function that can serve requests from either the native SDK or hybrid SDKs; they
 * will have different structures/objects available, these parameters are the common elements
 * needed to construct the payload dictionary.
 */
SENTRY_EXTERN NSMutableDictionary<NSString *, id> *_Nullable sentry_serializedTraceProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages, SentryHubInternal *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif // SENTRY_HAS_UIKIT
);

SENTRY_EXTERN NSMutableDictionary<NSString *, id> *sentry_serializedContinuousProfileChunk(
    SentryId *profileID, SentryId *chunkID, NSDictionary<NSString *, id> *profileData,
    NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages, SentryHubInternal *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif
);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
