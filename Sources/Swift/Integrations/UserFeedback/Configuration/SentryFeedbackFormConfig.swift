// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/**
 * Settings to control the behavior, appearance, and callbacks of a manually presented feedback form.
 */
@objcMembers
public final class SentryFeedbackFormConfig: NSObject {
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

    lazy var messageLabelContents = fullLabelText(labelText: messageLabel, required: true)

    /**
     * The placeholder for the feedback description input field.
     * - note: Default: `"What's the bug? What did you expect?"`
     */
    public var messagePlaceholder: String = "What's the bug? What did you expect?"

    public lazy var messageTextViewAccessibilityLabel: String = messagePlaceholder

    /**
     * The label shown next to an input field that is required.
     * - note: Default: `"(Required)"`
     */
    public var isRequiredLabel: String = "(Required)"

    // MARK: Screenshots

    /**
     * The label of the button to remove the screenshot from the form.
     * - note: Default: `"Remove screenshot"`
     */
    public var removeScreenshotButtonLabel: String = "Remove screenshot"

    public lazy var removeScreenshotButtonAccessibilityLabel = removeScreenshotButtonLabel

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

    lazy var nameLabelContents = fullLabelText(labelText: nameLabel, required: isNameRequired)

    /**
     * The placeholder for the name input field.
     * - note: Default: `"Your Name"`
     * - note: ignored if `showName` is `false`.
     */
    public var namePlaceholder: String = "Your Name"

    public lazy var nameTextFieldAccessibilityLabel = namePlaceholder

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

    lazy var emailLabelContents = fullLabelText(labelText: emailLabel, required: isEmailRequired)

    /**
     * The placeholder for the email input field.
     * - note: Default: `"your.email@example.org"`
     */
    public var emailPlaceholder: String = "your.email@example.org"

    public lazy var emailTextFieldAccessibilityLabel = "Your email address"

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
    public lazy var submitButtonAccessibilityLabel: String = submitButtonLabel

    /**
     * The label of cancel buttons used in the feedback form.
     * - note: Default: `"Cancel"`
     */
    public var cancelButtonLabel: String = "Cancel"

    /**
     * The accessibility label of the form's "Cancel" button.
     * - note: Default: `cancelButtonLabel` value
     */
    public lazy var cancelButtonAccessibilityLabel: String = cancelButtonLabel

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

    /**
     * Whether or not to show animations, like for presenting and dismissing the form.
     * - note: Default: `true`.
     */
    public var animations: Bool = true

    /**
     * Settings for overriding theming components for the feedback form.
     */
    public var theme = SentryUserFeedbackThemeConfiguration()

    /**
     * Called when the feedback form is opened.
     * - note: Default: `nil`
     */
    public var onFormOpen: (() -> Void)?

    /**
     * Called when the feedback form is closed.
     * - note: Default: `nil`
     */
    public var onFormClose: (() -> Void)?

    /**
     * Called when feedback is successfully submitted via the form, indicating that the
     * user correctly filled out the form and confirmed submission. The data dictionary contains the feedback details.
     * - note: Default: `nil`
     */
    public var onSubmitSuccess: (([String: Any]) -> Void)?

    /**
     * Called when there is an error submitting feedback via the form, like missing
     * required inputs. The error object contains details of the error.
     * - note: Default: `nil`
     */
    public var onSubmitError: ((Error) -> Void)?

    // MARK: Derived properties

    lazy var textEffectiveHeightCenter: CGFloat = {
        theme.font.familyName == "Damascus" ? theme.font.lineHeight / 2 + theme.font.lineHeight - theme.font.capHeight : theme.font.capHeight / 2
    }()

    /// The ratio of the configured font size to the system default font size, to know how large to scale things like the icon and lozenge shape.
    lazy var scaleFactor = calculateScaleFactor()

    func calculateScaleFactor() -> CGFloat {
        let fontSize = theme.font.pointSize
        guard fontSize > 0 else {
            return 1
        }

        return fontSize / UIFont.systemFontSize
    }

    /// Too much padding as the font size grows larger makes the button look weird with lots of negative space. Keeping the padding constant looks weird if the text is too small. So, scale it down below system default font sizes, but keep it fixed with larger font sizes.
    lazy var paddingScaleFactor = calculatePaddingScaleFactor()

    func calculatePaddingScaleFactor() -> CGFloat {
        scaleFactor > 1 ? 1 : scaleFactor
    }

    func recalculateScaleFactors() {
        scaleFactor = calculateScaleFactor()
        paddingScaleFactor = calculatePaddingScaleFactor()
    }

    // MARK: Layout

    let padding: CGFloat = 16
    let spacing: CGFloat = 8
    let margin: CGFloat = 32

    @objc public override init() {
        super.init()
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
