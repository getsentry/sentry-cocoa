@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// API for interacting with the feature User Feedback
@available(iOSApplicationExtension, unavailable)
@objc public final class SentryFeedbackAPI: NSObject {

    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @objc public func showWidget() {
        Self.getIntegration()?.driver.showWidget()
    }

    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @objc public func hideWidget() {
        Self.getIntegration()?.driver.hideWidget()
    }

    /// Show the feedback form using the best available presenter.
    ///
    /// The SDK shows the form from the configured custom button host, widget host, foreground
    /// window scene presenter, or first available key-window presenter.
    ///
    /// - Parameter image: An optional image to attach to the feedback form.
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured,
    /// no presenter is available, or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @discardableResult
    @objc(showWithImage:)
    public func show(image: UIImage? = nil) -> Bool {
        return Self.getIntegration()?.driver.showForm(screenshot: image) ?? false
    }

    static func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
