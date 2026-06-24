#import "SentrySamplerDecisionHelper.h"
#import "SentrySwift.h"

bool
sentry_samplerDecisionEquals(
    SentrySamplerDecision *_Nullable samplerDecision, SentrySampleDecision expected)
{
    if (samplerDecision == nil) {
        return false;
    }
    return samplerDecision.decision == expected;
}
