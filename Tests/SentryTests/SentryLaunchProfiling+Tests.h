#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentrySamplerDecision;
@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    BOOL shouldProfile;
    SentrySamplerDecision *_Nullable tracesDecision;
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

SentryLaunchProfileConfig sentry_shouldProfileNextLaunch(SentryOptions *options);

NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate;
NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate;

SentryTransactionContext *sentry_context(NSNumber *tracesRate);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
