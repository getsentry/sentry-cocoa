import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * Settings for whether to show the widget and how it should appear.
 */
@objc public class SentryUserFeedbackWidgetConfiguration: NSObject {
    /**
     * Injects the Feedback widget into the application UI when the integration is added. Set to `false`
     * if you want to call `attachToButton()` or `createWidget()` directly, or only want to show the
     * widget on certain views.
     * - note: Default: `true`
     */
    @objc public var autoInject: Bool = true
    
    /**
     * The label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `"Report a Bug"`
     */
    @objc public var triggerLabel: String = "Report a Bug"
    
    /**
     * The accessibility label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `triggerLabel` value
     */
    @objc public var triggerAccessibilityLabel: String?
    
    /**
     * The window level of the widget.
     * - note: Default: `UIWindow.Level.normal + 1`
     */
    @objc public var windowLevel: UIWindow.Level = UIWindow.Level.normal + 1
    
    /**
     * The location for positioning the widget.
     * - note: Default: `[.bottom, .right]`
     */
    @objc public var location: UIRectEdge = [.bottom, .right]
    
    /**
     * The distance to use from the widget button to the superview's `layoutMarginsGuide`.
     * - note: Default: `UIOffset.zero`
     */
    @objc public var layoutOffset: UIOffset = UIOffset.zero
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
