#if os(iOS) && !SENTRY_NO_UIKIT

@_implementationOnly import _SentryPrivate

//@available(iOS 13.0, *)
//@objc public class SentryFeedbackAPI: NSObject {
//
//    /**
//     * Show the feedback widget button.
//     * @warning This is an experimental feature and may still have bugs.
//     * @seealso See @c SentryOptions.configureUserFeedback to configure the widget.
//     * @note User feedback widget is only available for iOS 13 or later.
//     */
//    @objc func showWidget() {
//        SentrySwiftHelpers.getFeedbackIntegration()?.showWidget()
//    }
//    
//    /**
//     * Hide the feedback widget button.
//     * @warning This is an experimental feature and may still have bugs.
//     * @seealso See @c SentryOptions.configureUserFeedback to configure the widget.
//     * @note User feedback widget is only available for iOS 13 or later.
//     */
//    @objc func hideWidget() {
//        SentrySwiftHelpers.getFeedbackIntegration()?.hideWidget()
//    }
//}

@available(iOS 13.0, *)
@objc public class SentryFeedbackAPI: NSObject {
    @objc public func showWidget() {
        SentrySwiftHelpers.getFeedbackIntegration()?.showWidget()
    }
    @objc public func hideWidget() {
        SentrySwiftHelpers.getFeedbackIntegration()?.hideWidget()
    }
}

@available(iOS 13.0, *)
@objc public class SentryT: NSObject {
    @objc public func showWidget() {
        SentrySwiftHelpers.getFeedbackIntegration()?.showWidget()
    }
    @objc public func hideWidget() {
        SentrySwiftHelpers.getFeedbackIntegration()?.hideWidget()
    }
}
#endif
