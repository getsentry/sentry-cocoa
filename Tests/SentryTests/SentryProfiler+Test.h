#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryProfiler+Private.h"

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryProfiler ()

NSMutableDictionary<NSString *, id> *serializedProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
);

+ (SentryProfiler *)getCurrentProfiler;

+ (void)sentry_resetConcurrencyTracking;

+ (NSUInteger)sentry_currentProfiledTracers;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
