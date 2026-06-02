@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// API for interacting with the feature User Feedback
@objc public final class SentryFeedbackAPI: NSObject {

    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @objc public func showWidget() {
        getIntegration()?.driver.showWidget()
    }

    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @objc public func hideWidget() {
        getIntegration()?.driver.hideWidget()
    }

    /// Show the feedback form using the best available presenter.
    ///
    /// The SDK shows the form from the key-window presenter in a foreground-active scene.
    ///
    /// The form uses the global configuration from `SentryOptions.configureUserFeedback`.
    /// - Important: Call this method from the main thread.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc public func show() {
        show(image: nil)
    }

    /// Show the feedback form using the best available presenter.
    ///
    /// The SDK shows the form from the key-window presenter in a foreground-active scene.
    ///
    /// The form uses the global configuration from `SentryOptions.configureUserFeedback`.
    /// - Parameter image: An optional image to attach to the feedback form.
    /// - Important: Call this method from the main thread.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(showWithImage:)
    public func show(image: UIImage?) {
        guard let presenter = SentryFeedbackFormPresenter.presentingViewController() else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return
        }

        guard let driver = getIntegration()?.driver else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback is not configured")
            return
        }

        driver.showForm(from: presenter, screenshot: image)
    }

    @available(iOSApplicationExtension, unavailable)
    private func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
