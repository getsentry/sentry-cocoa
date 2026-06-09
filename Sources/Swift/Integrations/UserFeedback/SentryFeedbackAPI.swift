@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// API for interacting with the feature User Feedback
@objc public final class SentryFeedbackAPI: NSObject {

    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: Present the feedback form from your own UI using `show(screenshot:)` or
    /// `SentrySDK.FeedbackForm` instead.
    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
    @objc public func showWidget() {
        getIntegration()?.driver.showWidget()
    }

    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: If you currently use the auto-injected widget, disable auto-injection while
    /// migrating to presenting the feedback form from your own UI.
    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
    @objc public func hideWidget() {
        getIntegration()?.driver.hideWidget()
    }

    /// Show the feedback form using the best available presenter.
    ///
    /// The SDK shows the form from the key-window presenter in a foreground-active scene.
    ///
    /// The form uses the global configuration from `SentryOptions.configureUserFeedback`.
    /// - Parameter screenshot: An optional screenshot to attach to the feedback form.
    /// - Important: Call this method from the main thread.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    public func show(screenshot: UIImage? = nil) {
        guard let driver = getIntegration()?.driver else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback is not configured")
            return
        }

        guard let presenter = SentryFeedbackFormPresenter.presentingViewController() else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return
        }

        driver.showForm(from: presenter, screenshot: screenshot)
    }

    @available(iOSApplicationExtension, unavailable)
    private func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
