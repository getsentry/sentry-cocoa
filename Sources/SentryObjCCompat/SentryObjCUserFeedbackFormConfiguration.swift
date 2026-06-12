// swiftlint:disable file_length missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

@objc(SentryObjCUserFeedbackFormConfiguration) public final class SentryObjCUserFeedbackFormConfiguration: NSObject {
    internal let wrapped: SentryUserFeedbackFormConfiguration

    internal init(_ wrapped: SentryUserFeedbackFormConfiguration) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryUserFeedbackFormConfiguration()
    }

    @objc public var useSentryUser: Bool {
        get { wrapped.useSentryUser }
        set { wrapped.useSentryUser = newValue }
    }

    @objc public var showBranding: Bool {
        get { wrapped.showBranding }
        set { wrapped.showBranding = newValue }
    }

    @objc public var formTitle: String {
        get { wrapped.formTitle }
        set { wrapped.formTitle = newValue }
    }

    @objc public var messageLabel: String {
        get { wrapped.messageLabel }
        set { wrapped.messageLabel = newValue }
    }

    @objc public var messagePlaceholder: String {
        get { wrapped.messagePlaceholder }
        set { wrapped.messagePlaceholder = newValue }
    }

    @objc public var messageTextViewAccessibilityLabel: String {
        get { wrapped.messageTextViewAccessibilityLabel }
        set { wrapped.messageTextViewAccessibilityLabel = newValue }
    }

    @objc public var isRequiredLabel: String {
        get { wrapped.isRequiredLabel }
        set { wrapped.isRequiredLabel = newValue }
    }

    @objc public var removeScreenshotButtonLabel: String {
        get { wrapped.removeScreenshotButtonLabel }
        set { wrapped.removeScreenshotButtonLabel = newValue }
    }

    @objc public var removeScreenshotButtonAccessibilityLabel: String {
        get { wrapped.removeScreenshotButtonAccessibilityLabel }
        set { wrapped.removeScreenshotButtonAccessibilityLabel = newValue }
    }

    @objc public var isNameRequired: Bool {
        get { wrapped.isNameRequired }
        set { wrapped.isNameRequired = newValue }
    }

    @objc public var showName: Bool {
        get { wrapped.showName }
        set { wrapped.showName = newValue }
    }

    @objc public var nameLabel: String {
        get { wrapped.nameLabel }
        set { wrapped.nameLabel = newValue }
    }

    @objc public var namePlaceholder: String {
        get { wrapped.namePlaceholder }
        set { wrapped.namePlaceholder = newValue }
    }

    @objc public var nameTextFieldAccessibilityLabel: String {
        get { wrapped.nameTextFieldAccessibilityLabel }
        set { wrapped.nameTextFieldAccessibilityLabel = newValue }
    }

    @objc public var isEmailRequired: Bool {
        get { wrapped.isEmailRequired }
        set { wrapped.isEmailRequired = newValue }
    }

    @objc public var showEmail: Bool {
        get { wrapped.showEmail }
        set { wrapped.showEmail = newValue }
    }

    @objc public var emailLabel: String {
        get { wrapped.emailLabel }
        set { wrapped.emailLabel = newValue }
    }

    @objc public var emailPlaceholder: String {
        get { wrapped.emailPlaceholder }
        set { wrapped.emailPlaceholder = newValue }
    }

    @objc public var emailTextFieldAccessibilityLabel: String {
        get { wrapped.emailTextFieldAccessibilityLabel }
        set { wrapped.emailTextFieldAccessibilityLabel = newValue }
    }

    @objc public var submitButtonLabel: String {
        get { wrapped.submitButtonLabel }
        set { wrapped.submitButtonLabel = newValue }
    }

    @objc public var submitButtonAccessibilityLabel: String {
        get { wrapped.submitButtonAccessibilityLabel }
        set { wrapped.submitButtonAccessibilityLabel = newValue }
    }

    @objc public var cancelButtonLabel: String {
        get { wrapped.cancelButtonLabel }
        set { wrapped.cancelButtonLabel = newValue }
    }

    @objc public var cancelButtonAccessibilityLabel: String {
        get { wrapped.cancelButtonAccessibilityLabel }
        set { wrapped.cancelButtonAccessibilityLabel = newValue }
    }

    @objc public var unexpectedErrorText: String {
        get { wrapped.unexpectedErrorText }
        set { wrapped.unexpectedErrorText = newValue }
    }

    @objc public var validationErrorMessage: ((Bool) -> String) {
        get { wrapped.validationErrorMessage }
        set { wrapped.validationErrorMessage = newValue }
    }
}
#endif

// swiftlint:enable file_length missing_docs
