#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// Settings to control the behavior and appearance of the User Feedback form.
@interface SentryObjCUserFeedbackFormConfiguration : NSObject

/**
 * Sets the email and name field text content to the values contained in the current scope's
 * user, if any.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL useSentryUser;

/**
 * Displays the Sentry logo inside of the form.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL showBranding;

/**
 * The title at the top of the feedback form.
 * @note Default value is @c "Report a Bug".
 */
@property (nonatomic, copy) NSString *formTitle;

/**
 * The label for the feedback description input field.
 * @note Default value is @c "Description".
 */
@property (nonatomic, copy) NSString *messageLabel;

/**
 * The placeholder for the feedback description input field.
 * @note Default value is @c "What's the bug? What did you expect?".
 */
@property (nonatomic, copy) NSString *messagePlaceholder;

/// The accessibility label for the feedback message input.
@property (nonatomic, copy) NSString *messageTextViewAccessibilityLabel;

/**
 * The label shown next to an input field that is required.
 * @note Default value is @c "(Required)".
 */
@property (nonatomic, copy) NSString *isRequiredLabel;

/**
 * The label of the button to remove the screenshot from the form.
 * @note Default value is @c "Remove screenshot".
 */
@property (nonatomic, copy) NSString *removeScreenshotButtonLabel;

/// The accessibility label for the remove screenshot button.
@property (nonatomic, copy) NSString *removeScreenshotButtonAccessibilityLabel;

/**
 * Requires the name field on the feedback form to be filled in.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL isNameRequired;

/**
 * Displays the name field on the feedback form.
 * @note Default value is @c YES.
 * @note Ignored if @c isNameRequired is @c YES.
 */
@property (nonatomic) BOOL showName;

/**
 * The label of the name input field.
 * @note Default value is @c "Name".
 */
@property (nonatomic, copy) NSString *nameLabel;

/**
 * The placeholder for the name input field.
 * @note Default value is @c "Your Name".
 */
@property (nonatomic, copy) NSString *namePlaceholder;

/// The accessibility label for the name input field.
@property (nonatomic, copy) NSString *nameTextFieldAccessibilityLabel;

/**
 * Requires the email field on the feedback form to be filled in.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL isEmailRequired;

/**
 * Displays the email field on the feedback form.
 * @note Default value is @c YES.
 * @note Ignored if @c isEmailRequired is @c YES.
 */
@property (nonatomic) BOOL showEmail;

/**
 * The label of the email input field.
 * @note Default value is @c "Email".
 */
@property (nonatomic, copy) NSString *emailLabel;

/**
 * The placeholder for the email input field.
 * @note Default value is @c "your.email@example.org".
 */
@property (nonatomic, copy) NSString *emailPlaceholder;

/// The accessibility label for the email input field.
@property (nonatomic, copy) NSString *emailTextFieldAccessibilityLabel;

/**
 * The label of the submit button used in the feedback form.
 * @note Default value is @c "Send Bug Report".
 */
@property (nonatomic, copy) NSString *submitButtonLabel;

/// The accessibility label of the form's submit button.
@property (nonatomic, copy) NSString *submitButtonAccessibilityLabel;

/**
 * The label of cancel buttons used in the feedback form.
 * @note Default value is @c "Cancel".
 */
@property (nonatomic, copy) NSString *cancelButtonLabel;

/// The accessibility label of the form's cancel button.
@property (nonatomic, copy) NSString *cancelButtonAccessibilityLabel;

/**
 * Message shown to the user when an unexpected error happens while submitting feedback.
 * @note Default value is @c "Unexpected client error.".
 */
@property (nonatomic, copy) NSString *unexpectedErrorText;

/**
 * Message shown to the user when the form fails validation.
 * @param multipleErrors Whether more than one field failed validation.
 * @return The validation error message prefix.
 */
@property (nonatomic, copy) NSString * (^validationErrorMessage)(BOOL multipleErrors);

/// Initializes form configuration with default values.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

#endif
