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
        Self.getIntegration()?.driver.showWidget()
    }

    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @objc public func hideWidget() {
        Self.getIntegration()?.driver.hideWidget()
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
    @available(iOSApplicationExtension, unavailable)
    @objc(showWithConfig:image:)
    public func show(config: SentryUserFeedbackConfiguration, image: UIImage? = nil) {
        guard let presenter = SentryFeedbackFormPresenter.presentingViewController() else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return
        }

        let form = SentryUserFeedbackFormController(config: config, image: image)
        presenter.present(form, animated: config.animations)
    }

    @available(iOSApplicationExtension, unavailable)
    static func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
