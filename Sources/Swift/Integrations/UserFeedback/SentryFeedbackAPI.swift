@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// API for interacting with the feature User Feedback
@available(iOSApplicationExtension, unavailable, message: "Sentry User Feedback UI cannot be used from app extensions.")
@objc public final class SentryFeedbackAPI: NSObject {

    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @objc public func showWidget() {
        getIntegration()?.driver.showWidget()
    }

    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @objc public func hideWidget() {
        getIntegration()?.driver.hideWidget()
    }

    /// Show the feedback form using the best available presenter.
    ///
    /// The SDK shows the form from the key-window presenter in a foreground-active scene.
    ///
    /// - Parameter config: The configuration for this feedback form instance.
    /// - Important: Call this method from the main thread.
    /// - warning: This is an experimental feature and may still have bugs.
    @objc(showWithConfig:)
    public func show(config: SentryUserFeedbackConfiguration) {
        show(config: config, image: nil)
    }

    /// Show the feedback form using the best available presenter.
    ///
    /// The SDK shows the form from the key-window presenter in a foreground-active scene.
    ///
    /// - Parameters:
    ///   - config: The configuration for this feedback form instance.
    ///   - image: An optional image to attach to the feedback form.
    /// - Important: Call this method from the main thread.
    /// - warning: This is an experimental feature and may still have bugs.
    @objc(showWithConfig:image:)
    public func show(config: SentryUserFeedbackConfiguration, image: UIImage? = nil) {
        guard let presenter = SentryFeedbackFormPresenter.presentingViewController() else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return
        }

        let form = SentryUserFeedbackFormController(config: config, image: image)
        presenter.present(form, animated: config.animations)
    }

    private func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
