import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * Settings for whether to show the widget and how it should appear.
 */
@available(iOS 13.0, *)
@objcMembers
public class SentryUserFeedbackWidgetConfiguration: NSObject {
    /**
     * Injects the Feedback widget into the application UI when the integration is added. Set to `false`
     * if you want to call `attachToButton()` or `createWidget()` directly, or only want to show the
     * widget on certain views.
     * - note: Default: `true`
     */
    public var autoInject: Bool = true
    
    /**
     * Whether or not to show animations, like for presenting and dismissing the form.
     * - note: Default: `true`.
     */
    public var animations: Bool = true
    
    /**
     * The label of the injected button that opens up the feedback form when clicked. If `nil`, no text is displayed and only the icon image is shown.
     * - note: Default: `"Report a Bug"`
     */
    public var labelText: String? = "Report a Bug"
    
    /**
     * Whether or not to show our icon along with the text in the button.
     * - note: Default: `true`.
     */
    public var showIcon: Bool = true
    
    /**
     * The accessibility label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `labelText` value
     */
    public var widgetAccessibilityLabel: String?
    
    /**
     * The window level of the widget.
     * - note: Default: `UIWindow.Level.normal + 1`
     */
    public var windowLevel: UIWindow.Level = UIWindow.Level.normal + 1
    
    /**
     * The location for positioning the widget.
     * - note: Default: `[.bottom, .right]`
     */
    public var location: NSDirectionalRectEdge = [.bottom, .trailing]
    
    /**
     * The distance to use from the widget button to the `safeAreaLayoutGuide` of the root view in the widget's container window.
     * - note: Default: `UIOffset.zero`
     */
    public var layoutUIOffset: UIOffset = UIOffset.zero
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
