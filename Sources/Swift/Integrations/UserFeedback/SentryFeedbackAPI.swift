@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UIKIT

@objc
public final class SentryFeedbackAPI: NSObject {
    
    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "Create an instance of SentryUserFeedbackFormController directly.")
    @objc public func showWidget() {
        getIntegration()?.driver.showWidget()
    }
    
    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "Create an instance of SentryUserFeedbackFormController directly.")
    @objc public func hideWidget() {
        getIntegration()?.driver.hideWidget()
    }
    
    @available(*, deprecated, message: "Create an instance of SentryUserFeedbackFormController directly.")
    private func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}
#endif
