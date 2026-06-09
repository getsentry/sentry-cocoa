import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/**
 * Settings for whether to show the widget and how it should appear.
 *
 * - note: The managed widget is deprecated and will be removed in v10.
 */
@objcMembers
public final class SentryUserFeedbackWidgetConfiguration: NSObject {
    private var _autoInject: Bool = true

    /**
     * Automatically inject the widget button into the application UI.
     * - note: Default: `true`
     * - warning: Does not currently work for SwiftUI apps. See https://docs.sentry.io/platforms/apple/user-feedback/#swiftui
     * - deprecated: The managed widget is deprecated and will be removed in v10. Present the
     * feedback form from your own UI instead.
     */
    public var autoInject: Bool {
        get {
            _autoInject
        }
        @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
        set {
            _autoInject = newValue
        }
    }

    let defaultLabelText = "Report a Bug"

    private var _labelText: String? = "Report a Bug"

    /**
     * The label of the injected button that opens up the feedback form when clicked. If `nil`, no
     * text is displayed and only the icon image is shown.
     * - note: Default: `"Report a Bug"`
     * - deprecated: The managed widget is deprecated and will be removed in v10. Present the
     * feedback form from your own UI instead.
     */
    public var labelText: String? {
        get {
            _labelText
        }
        @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
        set {
            _labelText = newValue
        }
    }

    private var _showIcon: Bool = true

    /**
     * Whether or not to show our icon along with the text in the button.
     * - note: Default: `true`.
     * - deprecated: The managed widget is deprecated and will be removed in v10. Present the
     * feedback form from your own UI instead.
     */
    public var showIcon: Bool {
        get {
            _showIcon
        }
        @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
        set {
            _showIcon = newValue
        }
    }

    private var _widgetAccessibilityLabel: String??

    /**
     * The accessibility label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `labelText` value
     * - deprecated: The managed widget is deprecated and will be removed in v10. Present the
     * feedback form from your own UI instead.
     */
    public var widgetAccessibilityLabel: String? {
        get {
            if let widgetAccessibilityLabel = _widgetAccessibilityLabel {
                return widgetAccessibilityLabel
            }
            return labelText ?? defaultLabelText
        }
        @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
        set {
            _widgetAccessibilityLabel = newValue
        }
    }

    private var _windowLevel: UIWindow.Level = UIWindow.Level.normal + 1

    /**
     * The window level of the widget.
     * - note: Default: `UIWindow.Level.normal + 1`
     * - deprecated: The managed widget is deprecated and will be removed in v10. Present the
     * feedback form from your own UI instead.
     */
    public var windowLevel: UIWindow.Level {
        get {
            _windowLevel
        }
        @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
        set {
            _windowLevel = newValue
        }
    }

    private var _location: NSDirectionalRectEdge = [.bottom, .trailing]

    /**
     * The location for positioning the widget.
     * - note: Default: `[.bottom, .right]`
     * - deprecated: The managed widget is deprecated and will be removed in v10. Present the
     * feedback form from your own UI instead.
     */
    public var location: NSDirectionalRectEdge {
        get {
            _location
        }
        @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
        set {
            _location = newValue
        }
    }

    private var _layoutUIOffset: UIOffset = UIOffset.zero

    /**
     * The distance to use from the widget button to the `safeAreaLayoutGuide` of the root view in the widget's container window.
     * - note: Default: `UIOffset.zero`
     * - deprecated: The managed widget is deprecated and will be removed in v10. Present the
     * feedback form from your own UI instead.
     */
    public var layoutUIOffset: UIOffset {
        get {
            _layoutUIOffset
        }
        @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10. Present the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:) instead.")
        set {
            _layoutUIOffset = newValue
        }
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
