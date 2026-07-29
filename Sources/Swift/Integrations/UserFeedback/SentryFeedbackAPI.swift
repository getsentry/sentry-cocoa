internal import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// API for interacting with the feature User Feedback
@objc public final class SentryFeedbackAPI: NSObject {

    #if !SDK_V10
    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    /// - seealso: Present the feedback form from your own UI using `show(screenshot:)` or
    /// `SentrySDK.FeedbackForm` instead.
    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
    @objc public func showWidget() {
        getIntegration()?.driver.showWidget()
    }

    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    /// - seealso: Present the feedback form from your own UI using `show(screenshot:)` or
    /// `SentrySDK.FeedbackForm` instead.
    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
    @objc public func hideWidget() {
        getIntegration()?.driver.hideWidget()
    }
    #endif

    /// Show the feedback form using the best available presenter, screenshot attachment, and optional form-specific configuration.
    ///
    /// The SDK chooses a suitable presenter/window and ignores noninteractive external displays.
    /// In multi-window apps this is best-effort and may choose a different active window;
    /// present `SentrySDK.FeedbackForm` yourself for exact control.
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

    /// Enables or disables the shake-gesture trigger for the feedback form at runtime.
    ///
    /// Sentry's options are applied synchronously during `SentrySDK.start`, so consumers that
    /// decide whether to offer feedback based on an asynchronous signal (e.g. a feature flag or a
    /// user role fetched at launch) cannot express that choice through `useShakeGesture` alone.
    /// Use this method to toggle shake-to-report after initialization.
    ///
    /// Requires the User Feedback integration to be configured (`SentryOptions.configureUserFeedback`);
    /// otherwise this is a no-op. Only affects iOS/iPadOS; a no-op on other platforms.
    /// - Parameter enabled: `true` to start presenting the feedback form on shake; `false` to stop.
    /// - Important: Call this method from the main thread.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc public func setShakeGestureEnabled(_ enabled: Bool) {
        guard let driver = getIntegration()?.driver else {
            SentrySDKLog.debug("Cannot toggle shake gesture — user feedback is not configured")
            return
        }
        driver.setShakeGestureEnabled(enabled)
    }

    @available(iOSApplicationExtension, unavailable)
    private func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
