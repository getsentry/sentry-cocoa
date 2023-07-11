#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryDebugMeta;
@class SentryId;
@class SentryProfilerState;
@class SentrySample;
#    if SENTRY_HAS_UIKIT
@class SentryScreenFrames;
#    endif // SENTRY_HAS_UIKIT
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

NSDictionary<NSString *, id> *serializedProfileData(NSDictionary<NSString *, id> *profileData,
    SentryTransaction *transaction, SentryId *profileID, NSString *truncationReason,
    NSString *environment, NSString *release, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
);

@interface
SentryProfiler ()

@property (strong, nonatomic) SentryProfilerState *_state;
@property (strong, nonatomic) SentryScreenFrames *_screenFrameData;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
