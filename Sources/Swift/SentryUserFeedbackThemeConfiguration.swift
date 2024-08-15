import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * Configuration class for overriding theming components for the User Feedback Widget.
 */
@available(iOSApplicationExtension 13.0, *)
class SentryUserFeedbackThemeConfiguration {
    /**
     * The default font to use.
     * - note: Defaults to the current system default.
     */
    var font: UIFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    
    /**
     * The window level of the widget.
     * - note: Default: `UIWindow.Level.normal + 1`
     */
    var widgetWindowLevel: UIWindow.Level = UIWindow.Level.normal + 1
    
    /**
     * The location for positioning the widget.
     * - note: Default: `[.bottom, .trailing]`
     */
    var widgetDirectionalLocation: UIDirectionalRectEdge = [.bottom, .trailing]
    
    /**
     * The distance to use from the widget button to the superview's `layoutMarginsGuide`.
     * - note: Default: `UIOffset.zero`
     */
    var widgetOffset: UIOffset = UIOffset.zero
    
    /**
     * Foreground text color.
     * - note: Default light mode: `rgb(43, 34, 51)`; dark mode: `rgb(235, 230, 239)`
     */
    var foreground: UIColor = UIColor { (traitCollection) -> UIColor in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(red: 235 / 255, green: 230 / 255, blue: 239 / 255, alpha: 1) : UIColor(red: 43 / 255, green: 34 / 255, blue: 51 / 255, alpha: 1)
    }
    
    /**
     * Background color of the widget (injected button and form).
     * - note: Default light mode: `rgb(255, 255, 255)`; dark mode: `rgb(41, 35, 47)`
     */
    var background: UIColor = UIColor { (traitCollection) -> UIColor in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(red: 41 / 255, green: 35 / 255, blue: 47 / 255, alpha: 1) : UIColor.white
    }
    
    /**
     * Foreground color for the submit button.
     * - note: Default: `rgb(255, 255, 255)` for both dark and light modes
     */
    var accentForeground: UIColor = UIColor.white
    
    /**
     * Background color for the submit button in light and dark modes.
     * - note: Default: `rgb(88, 74, 192)` for both light and dark modes
     */
    var accentBackground: UIColor = UIColor(red: 88 / 255, green: 74 / 255, blue: 192 / 255, alpha: 1)
    
    /**
     * Color used for success-related components (such as text color when feedback is submitted successfully).
     * - note: Default light mode: `rgb(38, 141, 117)`; dark mode: `rgb(45, 169, 140)`
     */
    var successColor: UIColor = UIColor { (traitCollection) -> UIColor in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(red: 45 / 255, green: 169 / 255, blue: 140 / 255, alpha: 1) : UIColor(red: 38 / 255, green: 141 / 255, blue: 117 / 255, alpha: 1)
    }
    
    /**
     * Color used for error-related components (such as text color when there's an error submitting feedback).
     * - note: Default light mode: `rgb(223, 51, 56)`; dark mode: `rgb(245, 84, 89)`
     */
    var errorColor: UIColor = UIColor { (traitCollection) -> UIColor in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(red: 245 / 255, green: 84 / 255, blue: 89 / 255, alpha: 1) : UIColor(red: 223 / 255, green: 51 / 255, blue: 56 / 255, alpha: 1)
    }
    
    /**
     * Normal outline color for form inputs.
     * - note: Default: `nil (system default)`
     */
    var outlineColor: UIColor?
    
    /**
     * Outline color for form inputs when focused.
     * - note: Default: `nil (system default)`
     */
    var outlineColorFocussed: UIColor?
    
    /**
     * Normal outline thickness for form inputs.
     * - note: Default: `nil (system default)`
     */
    var outlineThickness: CGFloat?
    
    /**
     * Outline thickness for form inputs when focused.
     * - note: Default: `nil (system default)`
     */
    var outlineThicknessFocussed: CGFloat?
    
    /**
     * Outline corner radius for form input elements.
     * - note: Default: `nil (system default)`
     */
    var cornerRadius: CGFloat?
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
