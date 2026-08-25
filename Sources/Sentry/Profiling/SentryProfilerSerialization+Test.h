#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#        import "SentryDefines.h"
#        import "SentryProfiler+Private.h"

@class SentryDebugMeta;
@class SentryHubInternal;

NS_ASSUME_NONNULL_BEGIN

#        if !SDK_V10
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeySlowFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrameRates;
#        endif // !SDK_V10

SENTRY_EXTERN NSString *sentry_profilerTruncationReasonName(SentryProfilerTruncationReason reason);

/**
 * An intermediate function that can serve requests from either the native SDK or hybrid SDKs; they
 * will have different structures/objects available, these parameters are the common elements
 * needed to construct the payload dictionary.
 */
SENTRY_EXTERN NSMutableDictionary<NSString *, id> *sentry_serializedTraceProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHubInternal *hub
#        if SENTRY_HAS_UIKIT && !SDK_V10
    ,
    SentryScreenFrames *gpuData
#        endif // SENTRY_HAS_UIKIT && !SDK_V10
);

NS_ASSUME_NONNULL_END

#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
