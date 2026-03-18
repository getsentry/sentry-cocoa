#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Trace sample decision flag.
 *
 * @see SentryTracesSamplerCallback
 */
typedef NS_ENUM(NSUInteger, SentrySampleDecision) {
    /** Used when the decision to sample a trace should be postponed. */
    kSentrySampleDecisionUndecided,

    /** The trace should be sampled. */
    kSentrySampleDecisionYes,

    /** The trace should not be sampled. */
    kSentrySampleDecisionNo
};

NS_ASSUME_NONNULL_END
