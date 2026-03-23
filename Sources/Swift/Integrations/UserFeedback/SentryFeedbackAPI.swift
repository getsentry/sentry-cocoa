@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

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

    /// Enable shake gesture to show the feedback form.
    /// Call this to dynamically enable shake-to-report at runtime.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc public func enableShakeGesture() {
        getIntegration()?.driver.enableShakeGesture()
    }

    /// Disable shake gesture for the feedback form.
    /// Call this to dynamically disable shake-to-report at runtime.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc public func disableShakeGesture() {
        getIntegration()?.driver.disableShakeGesture()
    }
    
    private func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}
#endif
