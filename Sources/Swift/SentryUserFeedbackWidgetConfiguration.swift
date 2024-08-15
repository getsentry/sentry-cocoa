import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

class SentryUserFeedbackWidgetConfiguration {
    /**
     * Injects the Feedback widget into the application UI when the integration is added. Set to `false`
     * if you want to call `attachToButton()` or `createWidget()` directly, or only want to show the
     * widget on certain views.
     * - note: Default: `true`
     */
    var autoInject: Bool = true
    
    /**
     * The label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `"Report a Bug"`
     */
    var triggerLabel: String = "Report a Bug"
    
    /**
     * The accessibility label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `triggerLabel` value
     */
    var triggerAccessibilityLabel: String?
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
