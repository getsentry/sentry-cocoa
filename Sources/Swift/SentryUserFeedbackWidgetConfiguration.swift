import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@objc public class SentryUserFeedbackWidgetConfiguration: NSObject {
    /**
     * Injects the Feedback widget into the application UI when the integration is added. Set to `false`
     * if you want to call `attachToButton()` or `createWidget()` directly, or only want to show the
     * widget on certain views.
     * - note: Default: `true`
     */
    public var autoInject: Bool = true
    
    /**
     * The label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `"Report a Bug"`
     */
    public var triggerLabel: String = "Report a Bug"
    
    /**
     * The accessibility label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `triggerLabel` value
     */
    public var triggerAccessibilityLabel: String?
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
