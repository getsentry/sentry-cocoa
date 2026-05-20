#import <Foundation/Foundation.h>

/// Where a user-feedback submission originated.
typedef NS_ENUM(NSInteger, SentryCompatFeedbackSource) {
    SentryCompatFeedbackSourceWidget = 0,
    SentryCompatFeedbackSourceCustom = 1,
};
