// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/**
 * Settings to control the behavior and appearance of the UI form.
 */
@objcMembers
public final class SentryUserFeedbackFormConfiguration: NSObject {
    // MARK: General settings
    
    /**
     * Sets the email and name field text content to the values contained in the current scope's
     * `SentryUser` instance, if any.
     * - seealso: `- [SentrySDK setUser:]`
     * - note: Default: `true`
     */
    public var useSentryUser: Bool = true
    
    /**
     * Displays the Sentry logo inside of the form.
     * - note: Default: `true`
     */
    public var showBranding: Bool = true
    
    /**
     * The title at the top of the feedback form.
     * - note: Default: `"Report a Bug"`
     */
    public var formTitle: String = "Report a Bug"
    
    /**
     * The label for the feedback description input field.
     * - note: Default: `"Description"`
     */
    public var messageLabel: String = "Description"
    
    var messageLabelContents: String {
        fullLabelText(labelText: messageLabel, required: true)
    }
    
    /**
     * The placeholder for the feedback description input field.
     * - note: Default: `"What's the bug? What did you expect?"`
     */
    public var messagePlaceholder: String = "What's the bug? What did you expect?"
    
    @nonobjc var messageTextViewAccessibilityLabelOverride: String?
    public var messageTextViewAccessibilityLabel: String {
        get { messageTextViewAccessibilityLabelOverride ?? messagePlaceholder }
        set { messageTextViewAccessibilityLabelOverride = newValue }
    }
    
    /**
     * The label shown next to an input field that is required.
     * - note: Default: `"(Required)"`
     */
    public var isRequiredLabel: String = "(Required)"
    
    // MARK: Screenshots
    
    /**
     * The label of the button to remove the screenshot from the form.
     * - note: Default: `"Remove screenshot"`
     * - note: ignored if `SentryUserFeedbackConfiguration.showFormForScreenshots` is `false`.
     */
    public var removeScreenshotButtonLabel: String = "Remove screenshot"
    
    @nonobjc var removeScreenshotButtonAccessibilityLabelOverride: String?
    public var removeScreenshotButtonAccessibilityLabel: String {
        get { removeScreenshotButtonAccessibilityLabelOverride ?? removeScreenshotButtonLabel }
        set { removeScreenshotButtonAccessibilityLabelOverride = newValue }
    }
    
    // MARK: Name
    
    /**
     * Requires the name field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    public var isNameRequired: Bool = false
    
    /**
     * Displays the name field on the feedback form.
     * - note: Default: `true`
     * - note: ignored if `isNameRequired` is `true`.
     */
    public var showName: Bool = true
    
    /**
     * The label of the name input field.
     * - note: Default: `"Name"`
     * - note: ignored if `showName` is `false`.
     */
    public var nameLabel: String = "Name"
    
    var nameLabelContents: String {
        fullLabelText(labelText: nameLabel, required: isNameRequired)
    }
    
    /**
     * The placeholder for the name input field.
     * - note: Default: `"Your Name"`
     * - note: ignored if `showName` is `false`.
     */
    public var namePlaceholder: String = "Your Name"
    
    @nonobjc var nameTextFieldAccessibilityLabelOverride: String?
    public var nameTextFieldAccessibilityLabel: String {
        get { nameTextFieldAccessibilityLabelOverride ?? namePlaceholder }
        set { nameTextFieldAccessibilityLabelOverride = newValue }
    }
    
    // MARK: Email
    
    /**
     * Requires the email field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    public var isEmailRequired: Bool = false
    
    /**
     * Displays the email field on the feedback form.
     * - note: Default: `true`
     * - note: ignored if `isEmailRequired` is `true`.
     */
    public var showEmail: Bool = true
    
    /**
     * The label of the email input field.
     * - note: Default: `"Email"`
     */
    public var emailLabel: String = "Email"
    
    var emailLabelContents: String {
        fullLabelText(labelText: emailLabel, required: isEmailRequired)
    }
    
    /**
     * The placeholder for the email input field.
     * - note: Default: `"your.email@example.org"`
     */
    public var emailPlaceholder: String = "your.email@example.org"
    
    @nonobjc var emailTextFieldAccessibilityLabelOverride: String?
    public var emailTextFieldAccessibilityLabel: String {
        get { emailTextFieldAccessibilityLabelOverride ?? "Your email address" }
        set { emailTextFieldAccessibilityLabelOverride = newValue }
    }
    
    // MARK: Buttons
    
    /**
     * The label of the submit button used in the feedback form.
     * - note: Default: `"Send Bug Report"`
     */
    public var submitButtonLabel: String = "Send Bug Report"
    
    /**
     * The accessibility label of the form's "Submit" button.
     * - note: Default: `submitButtonLabel` value
     */
    @nonobjc var submitButtonAccessibilityLabelOverride: String?
    public var submitButtonAccessibilityLabel: String {
        get { submitButtonAccessibilityLabelOverride ?? submitButtonLabel }
        set { submitButtonAccessibilityLabelOverride = newValue }
    }
    
    /**
     * The label of cancel buttons used in the feedback form.
     * - note: Default: `"Cancel"`
     */
    public var cancelButtonLabel: String = "Cancel"
    
    /**
     * The accessibility label of the form's "Cancel" button.
     * - note: Default: `cancelButtonLabel` value
     */
    @nonobjc var cancelButtonAccessibilityLabelOverride: String?
    public var cancelButtonAccessibilityLabel: String {
        get { cancelButtonAccessibilityLabelOverride ?? cancelButtonLabel }
        set { cancelButtonAccessibilityLabelOverride = newValue }
    }
    
    func fullLabelText(labelText: String, required: Bool) -> String {
        required ? labelText + " " + isRequiredLabel : labelText
    }
    
    /**
     * Message shown to the user when an unexpected error happens while submitting feedback.
     * - note: Default: `"Unexpected client error."`
     */
    public var unexpectedErrorText: String = "Unexpected client error."
    
    /**
     * Message shown to the user when the form fails the validation.
     * - note: Default: `"You must provide all required information before submitting. Please check the following field(s)"`
     */
    public var validationErrorMessage: (Bool) -> String = { multipleErrors in
        return "You must provide all required information before submitting. Please check the following field\(multipleErrors ? "s" : ""):"
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
