@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UIKIT

@objc
public final class SentryFeedbackAPI: NSObject {
    
    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @objc public func showWidget() {
        SentryFeedbackAPIHelper.showWidget()
    }
    
    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @objc public func hideWidget() {
        SentryFeedbackAPIHelper.hideWidget()
    }
}
#endif
