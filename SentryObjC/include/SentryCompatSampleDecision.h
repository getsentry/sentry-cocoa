#import <Foundation/Foundation.h>

/// Trace sample decision.
typedef NS_ENUM(NSUInteger, SentryCompatSampleDecision) {
    SentryCompatSampleDecisionUndecided = 0,
    SentryCompatSampleDecisionYes = 1,
    SentryCompatSampleDecisionNo = 2,
};
