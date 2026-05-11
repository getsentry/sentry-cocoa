#import <Foundation/Foundation.h>

/**
 * Source of a user feedback submission.
 */
typedef NS_ENUM(NSInteger, SentryFeedbackSource) {
    SentryFeedbackSourceWidget = 0,
    SentryFeedbackSourceCustom
};
