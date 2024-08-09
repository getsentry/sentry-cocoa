#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryUserFeedbackThemeOverrides;

typedef void (^SentryUserFeedbackWidgetThemeOverridesBuilder)(SentryUserFeedbackThemeOverrides *);

typedef enum : NSUInteger {
    kSentryFeedbackWidgetColorSchemeSystem,
    kSentryFeedbackWidgetColorSchemeLight,
    kSentryFeedbackWidgetColorSchemeDark,
} SentryFeedbackWidgetColorScheme;

@interface SentryUserFeedbackWidgetConfiguration : NSObject
/**
 * Injects the Feedback widget into the application when the integration is added. Set to @c NO if
 * you want to call @c -[SentryUserFeedbackIntegration @c attachToButton:] or @c
 * -[SentryUserFeedbackIntegration @c createWidget] directly, or only want to show the widget on
 * certain views.
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL autoInject;

/**
 * Displays the Sentry logo inside of the form.
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL showBranding;

/**
 * The color theme to use for the widget and form. @c kSentryFeedbackWidgetColorSchemeSystem will
 * use the OS color scheme.
 * @note Default: @c kSentryFeedbackWidgetColorSchemeSystem
 */
@property (nonatomic, assign) SentryFeedbackWidgetColorScheme colorScheme;

/**
 * Tags to set on the feedback event. This is a dictionary where keys are strings
 * and values can be different data types such as @c NSNumber, @c NSString, etc.
 * @note Default: @{}
 */
@property (nonatomic, copy) NSDictionary<NSString *, id> *tags;

/**
 * Displays the name field on the feedback form.
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL showName;

/**
 * Displays the email field on the feedback form.
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL showEmail;

/**
 * Allows the user to send a screenshot attachment with their feedback.
 * @note Default: @c YES
 * @note For self-hosted, release 24.4.2 is also required.
 */
@property (nonatomic, assign) BOOL enableScreenshot;

/**
 * Requires the name field on the feedback form to be filled in.
 * @note Default: @c NO
 * @warning If @c showName is @c NO but this property is @c YES, then @c showName will be ignored.
 */
@property (nonatomic, assign) BOOL isNameRequired;

/**
 * Requires the email field on the feedback form to be filled in.
 * @note Default: @c NO
 * @warning If @c showEmail is @c NO but this property is @c YES, then @c showEmail will be ignored.
 */
@property (nonatomic, assign) BOOL isEmailRequired;

/**
 * Sets the email and name fields to the corresponding Sentry SDK user fields.
 * @note Default: @{ @"email": @"email", @"name": @"username" }
 */
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *useSentryUser;

/**
 * The label of the injected button that opens up the feedback form when clicked.
 * @note Default: @"Report a Bug"
 */
@property (nonatomic, copy) NSString *triggerLabel;

/**
 * The accessibility label of the injected button that opens up the feedback form when clicked.
 * @note Default: @c triggerLabel value
 */
@property (nonatomic, copy) NSString *triggerAccessibilityLabel;

/**
 * The title at the top of the feedback form.
 * @note Default: @"Report a Bug"
 */
@property (nonatomic, copy) NSString *formTitle;

/**
 * The label of the submit button used in the feedback form.
 * @note Default: @"Send Bug Report"
 */
@property (nonatomic, copy) NSString *submitButtonLabel;

/**
 * The label of cancel buttons used in the feedback form.
 * @note Default: @"Cancel"
 */
@property (nonatomic, copy) NSString *cancelButtonLabel;

/**
 * The label of confirm buttons used in the feedback form.
 * @note Default: @"Confirm"
 */
@property (nonatomic, copy) NSString *confirmButtonLabel;

/**
 * The label of the button to add a screenshot to the form.
 * @note Default: @"Add a screenshot"
 */
@property (nonatomic, copy) NSString *addScreenshotButtonLabel;

/**
 * The label of the button to remove the screenshot from the form.
 * @note Default: @"Remove screenshot"
 */
@property (nonatomic, copy) NSString *removeScreenshotButtonLabel;

/**
 * The label of the name input field.
 * @note Default: @"Name"
 */
@property (nonatomic, copy) NSString *nameLabel;

/**
 * The placeholder for the name input field.
 * @note Default: @"Your Name"
 */
@property (nonatomic, copy) NSString *namePlaceholder;

/**
 * The label of the email input field.
 * @note Default: @"Email"
 */
@property (nonatomic, copy) NSString *emailLabel;

/**
 * The placeholder for the email input field.
 * @note Default: @"your.email@example.org"
 */
@property (nonatomic, copy) NSString *emailPlaceholder;

/**
 * The label shown next to an input field that is required.
 * @note Default: @"(required)"
 */
@property (nonatomic, copy) NSString *isRequiredLabel;

/**
 * The label for the feedback description input field.
 * @note Default: @"Description"
 */
@property (nonatomic, copy) NSString *messageLabel;

/**
 * The placeholder for the feedback description input field.
 * @note Default: @"What's the bug? What did you expect?"
 */
@property (nonatomic, copy) NSString *messagePlaceholder;

/**
 * The message displayed after a successful feedback submission.
 * @note Default: @"Thank you for your report!"
 */
@property (nonatomic, copy) NSString *successMessageText;

/**
 * Builder for light mode theme overrides.
 * @note Default: @c nil
 */
@property (nonatomic, copy, nullable)
    SentryUserFeedbackWidgetThemeOverridesBuilder lightThemeOverrides;

/**
 * Builder for dark mode theme overrides.
 * @note Default: @c nil
 */
@property (nonatomic, copy, nullable)
    SentryUserFeedbackWidgetThemeOverridesBuilder darkThemeOverrides;

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
