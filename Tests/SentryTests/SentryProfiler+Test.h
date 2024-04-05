#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryInternalDefines.h"
#    import "SentryProfiler+Private.h"

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryProfiler ()

+ (SentryProfiler *)getCurrentProfiler;

+ (void)resetConcurrencyTracking;

+ (NSUInteger)currentProfiledTracers;

SENTRY_EXTERN NSString *profilerTruncationReasonName(SentryProfilerTruncationReason reason);

/**
 * An intermediate function that can serve requests from either the native SDK or hybrid SDKs; they
 * will have different structures/objects available, these parameters are the common elements
 * needed to construct the payload dictionary.
 */
SENTRY_EXTERN NSMutableDictionary<NSString *, id> *serializedProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
);

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
