import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * Settings to control the behavior and appearance of the UI form.
 */
@objc public class SentryUserFeedbackFormConfiguration: NSObject {
    // MARK: General settings
    
    /**
     * Displays the Sentry logo inside of the form.
     * - note: Default: `true`
     */
    @objc public var showBranding: Bool = true
    
    /**
     * The title at the top of the feedback form.
     * - note: Default: `"Report a Bug"`
     */
    @objc public var formTitle: String = "Report a Bug"
    
    /**
     * The label for the feedback description input field.
     * - note: Default: `"Description"`
     */
    @objc public var messageLabel: String = "Description"
    
    /**
     * The placeholder for the feedback description input field.
     * - note: Default: `"What's the bug? What did you expect?"`
     */
    @objc public var messagePlaceholder: String = "What's the bug? What did you expect?"
    
    /**
     * The label shown next to an input field that is required.
     * - note: Default: `"(required)"`
     */
    @objc public var isRequiredLabel: String = "(required)"
    
    /**
     * The message displayed after a successful feedback submission.
     * - note: Default: `"Thank you for your report!"`
     */
    @objc public var successMessageText: String = "Thank you for your report!"
    
    // MARK: Screenshots
    
    /**
     * Allows the user to send a screenshot attachment with their feedback.
     * - note: Default: `true`
     */
    @objc public var enableScreenshot: Bool = true
    
    /**
     * The label of the button to add a screenshot to the form.
     * - note: Default: `"Add a screenshot"`
     * - note: ignored if `enableScreenshot` is `false`.`
     */
    @objc public var addScreenshotButtonLabel: String = "Add a screenshot"
    
    /**
     * The label of the button to remove the screenshot from the form.
     * - note: Default: `"Remove screenshot"`
     * - note: ignored if `enableScreenshot` is `false`.
     */
    @objc public var removeScreenshotButtonLabel: String = "Remove screenshot"
    
    // MARK: Name
    
    /**
     * Requires the name field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    @objc public var isNameRequired: Bool = false
    
    /**
     * Displays the name field on the feedback form.
     * - note: Default: `true`
     * - note: ignored if `isNameRequired` is `true`.
     */
    @objc public var showName: Bool = true
    
    /**
     * The label of the name input field.
     * - note: Default: `"Name"`
     * - note: ignored if `showName` is `false`.
     */
    @objc public var nameLabel: String = "Name"
    
    /**
     * The placeholder for the name input field.
     * - note: Default: `"Your Name"`
     * - note: ignored if `showName` is `false`.
     */
    @objc public var namePlaceholder: String = "Your Name"
    
    // MARK: Email
    
    /**
     * Requires the email field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    @objc public var isEmailRequired: Bool = false
    
    /**
     * Displays the email field on the feedback form.
     * - note: Default: `true`
     * - note: ignored if `isEmailRequired` is `true`.
     */
    @objc public var showEmail: Bool = true
    
    /**
     * The label of the email input field.
     * - note: Default: `"Email"`
     */
    @objc public var emailLabel: String = "Email"
    
    /**
     * The placeholder for the email input field.
     * - note: Default: `"your.email@example.org"`
     */
    @objc public var emailPlaceholder: String = "your.email@example.org"
    
    // MARK: Buttons
    
    /**
     * The label of the submit button used in the feedback form.
     * - note: Default: `"Send Bug Report"`
     */
    @objc public var submitButtonLabel: String = "Send Bug Report"
    
    /**
     * The label of cancel buttons used in the feedback form.
     * - note: Default: `"Cancel"`
     */
    @objc public var cancelButtonLabel: String = "Cancel"
    
    /**
     * The label of confirm buttons used in the feedback form.
     * - note: Default: `"Confirm"`
     */
    @objc public var confirmButtonLabel: String = "Confirm"
    
    // MARK: Theme
    
    /**
     * Builder for light mode theme overrides.
     * - note: Default: `nil`
     */
    @objc public var lightThemeOverrides: ((SentryUserFeedbackThemeConfiguration) -> Void)?
    
    /**
     * Builder for dark mode theme overrides.
     * - note: Default: `nil`
     */
    @objc public var darkThemeOverrides: ((SentryUserFeedbackThemeConfiguration) -> Void)?
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
