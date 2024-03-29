#import "SentryDefines.h"
#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentrySamplerDecision;
@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    BOOL shouldProfile;
#    if SENTRY_PROFILING_MODE_LEGACY
    SentrySamplerDecision *_Nullable tracesDecision;
#    endif // SENTRY_PROFILING_MODE_LEGACY
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

SENTRY_EXTERN SentryLaunchProfileConfig shouldProfileNextLaunch(SentryOptions *options);

#    if SENTRY_PROFILING_MODE_LEGACY
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate;
#    endif // SENTRY_PROFILING_MODE_LEGACY
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate;

#    if SENTRY_PROFILING_MODE_LEGACY
SENTRY_EXTERN SentryTransactionContext *context(NSNumber *tracesRate);
SENTRY_EXTERN SentryTracerConfiguration *config(NSNumber *profilesRate);
#    endif // SENTRY_PROFILING_MODE_LEGACY

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
