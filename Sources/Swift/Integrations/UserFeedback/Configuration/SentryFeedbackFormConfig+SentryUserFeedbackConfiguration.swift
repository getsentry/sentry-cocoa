// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

extension SentryFeedbackFormConfig {
    // Converts the managed integration config after its builder closures have been applied.
    convenience init(userFeedbackConfiguration: SentryUserFeedbackConfiguration) {
        self.init()

        animations = userFeedbackConfiguration.animations
        onFormOpen = userFeedbackConfiguration.onFormOpen
        onFormClose = userFeedbackConfiguration.onFormClose
        onSubmitSuccess = userFeedbackConfiguration.onSubmitSuccess
        onSubmitError = userFeedbackConfiguration.onSubmitError

        copyFormConfig(userFeedbackConfiguration.formConfig)
        copyTheme(userFeedbackConfiguration.theme)
    }

    private func copyFormConfig(_ formConfig: SentryUserFeedbackFormConfiguration) {
        useSentryUser = formConfig.useSentryUser
        showBranding = formConfig.showBranding
        formTitle = formConfig.formTitle
        messageLabel = formConfig.messageLabel
        messagePlaceholder = formConfig.messagePlaceholder
        messageTextViewAccessibilityLabel = formConfig.messageTextViewAccessibilityLabel
        isRequiredLabel = formConfig.isRequiredLabel
        removeScreenshotButtonLabel = formConfig.removeScreenshotButtonLabel
        removeScreenshotButtonAccessibilityLabel = formConfig.removeScreenshotButtonAccessibilityLabel
        isNameRequired = formConfig.isNameRequired
        showName = formConfig.showName
        nameLabel = formConfig.nameLabel
        namePlaceholder = formConfig.namePlaceholder
        nameTextFieldAccessibilityLabel = formConfig.nameTextFieldAccessibilityLabel
        isEmailRequired = formConfig.isEmailRequired
        showEmail = formConfig.showEmail
        emailLabel = formConfig.emailLabel
        emailPlaceholder = formConfig.emailPlaceholder
        emailTextFieldAccessibilityLabel = formConfig.emailTextFieldAccessibilityLabel
        submitButtonLabel = formConfig.submitButtonLabel
        submitButtonAccessibilityLabel = formConfig.submitButtonAccessibilityLabel
        cancelButtonLabel = formConfig.cancelButtonLabel
        cancelButtonAccessibilityLabel = formConfig.cancelButtonAccessibilityLabel
        unexpectedErrorText = formConfig.unexpectedErrorText
        validationErrorMessage = formConfig.validationErrorMessage
    }

    private func copyTheme(_ sourceTheme: SentryUserFeedbackThemeConfiguration) {
        theme.fontFamily = sourceTheme.fontFamily
        theme.font = sourceTheme.font
        theme.headerFont = sourceTheme.headerFont
        theme.titleFont = sourceTheme.titleFont
        theme.foreground = sourceTheme.foreground
        theme.background = sourceTheme.background
        theme.submitForeground = sourceTheme.submitForeground
        theme.submitBackground = sourceTheme.submitBackground
        theme.buttonForeground = sourceTheme.buttonForeground
        theme.buttonBackground = sourceTheme.buttonBackground
        theme.errorColor = sourceTheme.errorColor
        if sourceTheme.outlineStyle == sourceTheme.defaultOutlineStyle {
            theme.outlineStyle = theme.defaultOutlineStyle
        } else {
            theme.outlineStyle = sourceTheme.outlineStyle
        }
        theme.inputBackground = sourceTheme.inputBackground
        theme.inputForeground = sourceTheme.inputForeground
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
