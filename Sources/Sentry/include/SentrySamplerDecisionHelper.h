#import "SentrySampleDecision.h"
#import <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySamplerDecision;

/**
 * Checks whether a @c SentrySamplerDecision matches the given @c SentrySampleDecision value.
 * ObjC++ (.mm) files cannot import the generated Swift header, so they only see the forward
 * declaration and cannot access properties directly. This C function bridges that gap.
 * Returns @c false when @c samplerDecision is @c nil.
 */
#if defined(__cplusplus)
extern "C" {
#endif
bool sentry_samplerDecisionEquals(
    SentrySamplerDecision *_Nullable samplerDecision, SentrySampleDecision expected);
#if defined(__cplusplus)
}
#endif

NS_ASSUME_NONNULL_END
