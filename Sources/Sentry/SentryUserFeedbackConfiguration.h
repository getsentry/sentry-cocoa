#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@class SentryUserFeedbackFormConfiguration;
@class SentryUserFeedbackWidgetConfiguration;

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryUserFeedbackWidgetConfigurationBuilder)(
    SentryUserFeedbackWidgetConfiguration *widget);
typedef void (^SentryUserFeedbackFormConfigurationBuilder)(
    SentryUserFeedbackFormConfiguration *uiForm);

@interface SentryUserFeedbackConfiguration : NSObject

/**
 * Configuration settings specific to the managed widget that displays the UI form.
 */
@property (nonatomic, copy, nullable) SentryUserFeedbackWidgetConfigurationBuilder widgetConfig;

/**
 * Configuration settings specific to the managed UI form to gather user input.
 */
@property (nonatomic, copy, nullable) SentryUserFeedbackFormConfigurationBuilder uiFormConfig;

/**
 * Tags to set on the feedback event. This is a dictionary where keys are strings
 * and values can be different data types such as @c NSNumber, @c NSString, etc.
 * @note Default: @c nil
 */
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *tags;

/**
 * Sets the email and name field text content to @c SentryUser.email and @c SentryUser.name .
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL useSentryUser;

/**
 * Called when the feedback form is opened.
 * @note Default: @c nil
 */
@property (nonatomic, copy, nullable) void (^onFormOpen)(void);

/**
 * Called when the feedback form is closed.
 * @note Default: @c nil
 */
@property (nonatomic, copy, nullable) void (^onFormClose)(void);

/**
 * Called when feedback is successfully submitted.
 * The data dictionary contains the feedback details.
 * @note Default: @c nil
 */
@property (nonatomic, copy, nullable) void (^onSubmitSuccess)(NSDictionary *data);

/**
 * Called when there is an error submitting feedback.
 * The error object contains details of the error.
 * @note Default: @c nil
 */
@property (nonatomic, copy, nullable) void (^onSubmitError)(NSError *error);

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
