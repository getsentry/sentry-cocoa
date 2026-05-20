#import <Foundation/Foundation.h>

/// Where a user-feedback submission originated.
typedef NS_ENUM(NSInteger, SOCSentryFeedbackSource) {
    SOCSentryFeedbackSourceWidget = 0,
    SOCSentryFeedbackSourceCustom = 1,
};
