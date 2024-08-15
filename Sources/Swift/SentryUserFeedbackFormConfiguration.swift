import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOSApplicationExtension 13.0, *)
@objc public class SentryUserFeedbackFormConfiguration: NSObject {
    /**
     * Displays the Sentry logo inside of the form.
     * - note: Default: `true`
     */
    public var showBranding: Bool = true
    
    /**
     * Displays the name field on the feedback form.
     * - note: Default: `true`
     */
    public var showName: Bool = true
    
    /**
     * Displays the email field on the feedback form.
     * - note: Default: `true`
     */
    public var showEmail: Bool = true
    
    /**
     * Allows the user to send a screenshot attachment with their feedback.
     * - note: Default: `true`
     */
    public var enableScreenshot: Bool = true
    
    /**
     * Requires the name field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    public var isNameRequired: Bool = false
    
    /**
     * Requires the email field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    public var isEmailRequired: Bool = false
    
    /**
     * The title at the top of the feedback form.
     * - note: Default: `"Report a Bug"`
     */
    public var formTitle: String = "Report a Bug"
    
    /**
     * The label of the submit button used in the feedback form.
     * - note: Default: `"Send Bug Report"`
     */
    public var submitButtonLabel: String = "Send Bug Report"
    
    /**
     * The label of cancel buttons used in the feedback form.
     * - note: Default: `"Cancel"`
     */
    public var cancelButtonLabel: String = "Cancel"
    
    /**
     * The label of confirm buttons used in the feedback form.
     * - note: Default: `"Confirm"`
     */
    public var confirmButtonLabel: String = "Confirm"
    
    /**
     * The label of the button to add a screenshot to the form.
     * - note: Default: `"Add a screenshot"`
     */
    public var addScreenshotButtonLabel: String = "Add a screenshot"
    
    /**
     * The label of the button to remove the screenshot from the form.
     * - note: Default: `"Remove screenshot"`
     */
    public var removeScreenshotButtonLabel: String = "Remove screenshot"
    
    /**
     * The label of the name input field.
     * - note: Default: `"Name"`
     */
    public var nameLabel: String = "Name"
    
    /**
     * The placeholder for the name input field.
     * - note: Default: `"Your Name"`
     */
    public var namePlaceholder: String = "Your Name"
    
    /**
     * The label of the email input field.
     * - note: Default: `"Email"`
     */
    public var emailLabel: String = "Email"
    
    /**
     * The placeholder for the email input field.
     * - note: Default: `"your.email@example.org"`
     */
    public var emailPlaceholder: String = "your.email@example.org"
    
    /**
     * The label shown next to an input field that is required.
     * - note: Default: `"(required)"`
     */
    public var isRequiredLabel: String = "(required)"
    
    /**
     * The label for the feedback description input field.
     * - note: Default: `"Description"`
     */
    public var messageLabel: String = "Description"
    
    /**
     * The placeholder for the feedback description input field.
     * - note: Default: `"What's the bug? What did you expect?"`
     */
    public var messagePlaceholder: String = "What's the bug? What did you expect?"
    
    /**
     * The message displayed after a successful feedback submission.
     * - note: Default: `"Thank you for your report!"`
     */
    public var successMessageText: String = "Thank you for your report!"
    
    /**
     * Builder for light mode theme overrides.
     * - note: Default: `nil`
     */
    public var lightThemeOverrides: ((SentryUserFeedbackThemeConfiguration) -> Void)?
    
    /**
     * Builder for dark mode theme overrides.
     * - note: Default: `nil`
     */
    public var darkThemeOverrides: ((SentryUserFeedbackThemeConfiguration) -> Void)?
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
