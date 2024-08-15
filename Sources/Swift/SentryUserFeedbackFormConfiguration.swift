import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOSApplicationExtension 13.0, *)
class SentryUserFeedbackFormConfiguration {
    /**
     * Displays the Sentry logo inside of the form.
     * - note: Default: `true`
     */
    var showBranding: Bool = true
    
    /**
     * Displays the name field on the feedback form.
     * - note: Default: `true`
     */
    var showName: Bool = true
    
    /**
     * Displays the email field on the feedback form.
     * - note: Default: `true`
     */
    var showEmail: Bool = true
    
    /**
     * Allows the user to send a screenshot attachment with their feedback.
     * - note: Default: `true`
     */
    var enableScreenshot: Bool = true
    
    /**
     * Requires the name field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    var isNameRequired: Bool = false
    
    /**
     * Requires the email field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    var isEmailRequired: Bool = false
    
    /**
     * The title at the top of the feedback form.
     * - note: Default: `"Report a Bug"`
     */
    var formTitle: String = "Report a Bug"
    
    /**
     * The label of the submit button used in the feedback form.
     * - note: Default: `"Send Bug Report"`
     */
    var submitButtonLabel: String = "Send Bug Report"
    
    /**
     * The label of cancel buttons used in the feedback form.
     * - note: Default: `"Cancel"`
     */
    var cancelButtonLabel: String = "Cancel"
    
    /**
     * The label of confirm buttons used in the feedback form.
     * - note: Default: `"Confirm"`
     */
    var confirmButtonLabel: String = "Confirm"
    
    /**
     * The label of the button to add a screenshot to the form.
     * - note: Default: `"Add a screenshot"`
     */
    var addScreenshotButtonLabel: String = "Add a screenshot"
    
    /**
     * The label of the button to remove the screenshot from the form.
     * - note: Default: `"Remove screenshot"`
     */
    var removeScreenshotButtonLabel: String = "Remove screenshot"
    
    /**
     * The label of the name input field.
     * - note: Default: `"Name"`
     */
    var nameLabel: String = "Name"
    
    /**
     * The placeholder for the name input field.
     * - note: Default: `"Your Name"`
     */
    var namePlaceholder: String = "Your Name"
    
    /**
     * The label of the email input field.
     * - note: Default: `"Email"`
     */
    var emailLabel: String = "Email"
    
    /**
     * The placeholder for the email input field.
     * - note: Default: `"your.email@example.org"`
     */
    var emailPlaceholder: String = "your.email@example.org"
    
    /**
     * The label shown next to an input field that is required.
     * - note: Default: `"(required)"`
     */
    var isRequiredLabel: String = "(required)"
    
    /**
     * The label for the feedback description input field.
     * - note: Default: `"Description"`
     */
    var messageLabel: String = "Description"
    
    /**
     * The placeholder for the feedback description input field.
     * - note: Default: `"What's the bug? What did you expect?"`
     */
    var messagePlaceholder: String = "What's the bug? What did you expect?"
    
    /**
     * The message displayed after a successful feedback submission.
     * - note: Default: `"Thank you for your report!"`
     */
    var successMessageText: String = "Thank you for your report!"
    
    /**
     * Builder for light mode theme overrides.
     * - note: Default: `nil`
     */
    var lightThemeOverrides: ((SentryUserFeedbackThemeConfiguration) -> Void)?
    
    /**
     * Builder for dark mode theme overrides.
     * - note: Default: `nil`
     */
    var darkThemeOverrides: ((SentryUserFeedbackThemeConfiguration) -> Void)?
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
