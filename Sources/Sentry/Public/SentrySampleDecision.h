#import <Foundation/Foundation.h>

/**
 * Trace sample decision flag.
 */
typedef NS_ENUM(NSUInteger, SentrySampleDecision) {
    /**
     * Used when the decision to sample a trace should be postponed.
     */
    kSentrySampleDecisionUndecided,

    /**
     * The trace should be sampled.
     */
    kSentrySampleDecisionYes,

    /**
     * The trace should not be sampled.
     */
    kSentrySampleDecisionNo
};

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentrySampleDecisionNameUndecided;
FOUNDATION_EXPORT NSString *const kSentrySampleDecisionNameYes;
FOUNDATION_EXPORT NSString *const kSentrySampleDecisionNameNo;

NSString *sampleDecisionName(SentrySampleDecision decision);

NS_ASSUME_NONNULL_END
