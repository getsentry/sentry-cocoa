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

    /// Show the feedback form using the best available presenter, screenshot attachment, and optional form-specific configuration.
    ///
    /// The SDK chooses a suitable presenter/window. Apps that need exact scene/window control
    /// should manually present `SentrySDK.FeedbackForm`.
    ///
    /// Per-presentation configuration only affects the displayed form. Widget, custom button,
    /// screenshot trigger, and shake gesture settings are global and ignored for individual presentations.
    /// - Parameters:
    ///   - screenshot: An optional screenshot to attach to the feedback form.
    ///   - configure: A closure to customize this feedback form presentation.
    /// - Important: Call this method from the main thread.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    public func show(
        screenshot: UIImage? = nil,
        configure: SentryUserFeedbackConfigurationCallback? = nil
    ) {
        guard let driver = getIntegration()?.driver else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback is not configured")
            return
        }

        guard let presenter = SentryFeedbackFormPresenter.presentingViewController() else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return
        }

        driver.showForm(from: presenter, screenshot: screenshot, configure: configure)
    }

    @available(iOSApplicationExtension, unavailable)
    private func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
