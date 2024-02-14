#import "SentryDefines.h"
#import "SentryLaunchProfiling.h"

@class SentrySamplerDecision;
@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    BOOL shouldProfile;
    SentrySamplerDecision *_Nullable tracesDecision;
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

SENTRY_EXTERN SentryLaunchProfileConfig shouldProfileNextLaunch(SentryOptions *options);

SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate;

SENTRY_EXTERN SentryTransactionContext *context(NSNumber *tracesRate);
SENTRY_EXTERN SentryTracerConfiguration *config(NSNumber *profilesRate);

NS_ASSUME_NONNULL_END
