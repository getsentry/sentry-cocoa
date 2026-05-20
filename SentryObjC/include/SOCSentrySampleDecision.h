#import <Foundation/Foundation.h>

/// Trace sample decision.
typedef NS_ENUM(NSUInteger, SOCSentrySampleDecision) {
    SOCSentrySampleDecisionUndecided = 0,
    SOCSentrySampleDecisionYes = 1,
    SOCSentrySampleDecisionNo = 2,
};
