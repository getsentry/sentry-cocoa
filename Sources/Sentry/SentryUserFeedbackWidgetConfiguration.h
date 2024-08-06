#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryUserFeedbackWidgetConfiguration : NSObject
/**
 * Injects the Feedback widget into the application when the integration is added.
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL autoInject;

/**
 * Displays the Sentry logo inside of the form.
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL showBranding;

/**
 * Shows the color theme choices. Options are "system", "light", or "dark".
 * "system" will use the OS color scheme.
 * @note Default: @"system"
 */
@property (nonatomic, copy) NSString *colorScheme;

/**
 * The id attribute of the <div> that contains the feedback widget.
 * @note Default: @"sentry-feedback"
 */
@property (nonatomic, copy) NSString *widgetId;

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
 */
@property (nonatomic, assign) BOOL enableScreenshot;

/**
 * Requires the name field on the feedback form to be filled in.
 * @note Default: @c NO
 */
@property (nonatomic, assign) BOOL isNameRequired;

/**
 * Requires the email field on the feedback form to be filled in.
 * @note Default: @c NO
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
 * The aria label of the injected button that opens up the feedback form when clicked.
 * If not provided, will default to triggerLabel or @"Report a Bug".
 * @note Default: @c nil
 */
@property (nonatomic, copy) NSString *triggerAriaLabel;

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
 * Customizes the theme for light mode by overriding default CSS variables.
 * Keys correspond to CSS properties such as background color, text color, etc.
 * @note Default: @c nil
 */
@property (nonatomic, copy) NSDictionary<NSString *, id> *themeLight;

/**
 * Customizes the theme for dark mode by overriding default CSS variables.
 * Keys correspond to CSS properties such as background color, text color, etc.
 * @note Default: @c nil
 */
@property (nonatomic, copy) NSDictionary<NSString *, id> *themeDark;

/**
 * Called when the feedback form is opened.
 * @note Default: @c nil
 */
@property (nonatomic, copy) void (^onFormOpen)(void);

/**
 * Called when the feedback form is closed.
 * @note Default: @c nil
 */
@property (nonatomic, copy) void (^onFormClose)(void);

/**
 * Called when feedback is successfully submitted.
 * The data dictionary contains the feedback details.
 * @note Default: @c nil
 */
@property (nonatomic, copy) void (^onSubmitSuccess)(NSDictionary *data);

/**
 * Called when there is an error submitting feedback.
 * The error object contains details of the error.
 * @note Default: @c nil
 */
@property (nonatomic, copy) void (^onSubmitError)(NSError *error);

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
