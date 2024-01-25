#import "SentryInternalDefines.h"
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

NS_ASSUME_NONNULL_END
