#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryDebugMeta;
@class SentryId;
@class SentryProfilerState;
@class SentrySample;
@class SentryHub;
#    if UIKIT_LINKED
@class SentryScreenFrames;
#    endif // UIKIT_LINKED
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

NSMutableDictionary<NSString *, id> *serializedProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if UIKIT_LINKED
    ,
    SentryScreenFrames *gpuData
#    endif // UIKIT_LINKED
);

@interface
SentryProfiler ()

@property (strong, nonatomic) SentryProfilerState *_state;
#    if UIKIT_LINKED
@property (strong, nonatomic) SentryScreenFrames *_screenFrameData;
#    endif // UIKIT_LINKED

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
