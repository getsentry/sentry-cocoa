#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import "SentryProfilerDefines.h"
#    import "SentryProfilingFrameMeasurements.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeySlowFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrameRates;

SENTRY_EXTERN NSString *sentry_profilerTruncationReasonName(SentryProfilerTruncationReason reason);

/** Serialize collected samples and metrics without SDK enrichment or lost-event accounting. */
SENTRY_EXTERN NSMutableDictionary<NSString *, id> *_Nullable sentry_serializedTraceProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif // SENTRY_HAS_UIKIT
);

SENTRY_EXTERN NSMutableDictionary<NSString *, id> *sentry_serializedContinuousProfileChunk(
    NSDictionary<NSString *, id> *profileData, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif
);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
