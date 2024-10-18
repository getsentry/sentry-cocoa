import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * Settings for overriding theming components for the User Feedback Widget and Form.
 */
@available(iOS 13.0, *)
@objcMembers
public class SentryUserFeedbackThemeConfiguration: NSObject {
    /**
     * The default font to use.
     * - note: Defaults to the current system default.
     */
    public var font: UIFont = UIFont.preferredFont(forTextStyle: .callout)
    
    /**
     * Foreground text color of the widget and form.
     * - note: Default light mode: `rgb(43, 34, 51)`; dark mode: `rgb(235, 230, 239)`
     */
    public var foreground = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor(red: 235 / 255, green: 230 / 255, blue: 239 / 255, alpha: 1) : UIColor(red: 43 / 255, green: 34 / 255, blue: 51 / 255, alpha: 1)
    
    /**
     * Background color of the widget and form.
     * - note: Default light mode: `rgb(255, 255, 255)`; dark mode: `rgb(41, 35, 47)`
     */
    public var background = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor(red: 41 / 255, green: 35 / 255, blue: 47 / 255, alpha: 1) : UIColor.white
    
    /**
     * Foreground color for the form submit button.
     * - note: Default: `rgb(255, 255, 255)` for both dark and light modes
     */
    public var accentForeground: UIColor = UIColor.white
    
    /**
     * Background color for the form submit button in light and dark modes.
     * - note: Default: `rgb(88, 74, 192)` for both light and dark modes
     */
    public var accentBackground: UIColor = UIColor(red: 88 / 255, green: 74 / 255, blue: 192 / 255, alpha: 1)
    
    /**
     * Color used for success-related components (such as text color when feedback is submitted successfully).
     * - note: Default light mode: `rgb(38, 141, 117)`; dark mode: `rgb(45, 169, 140)`
     */
    public var successColor = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor(red: 45 / 255, green: 169 / 255, blue: 140 / 255, alpha: 1) : UIColor(red: 38 / 255, green: 141 / 255, blue: 117 / 255, alpha: 1)
    
    /**
     * Color used for error-related components (such as text color when there's an error submitting feedback).
     * - note: Default light mode: `rgb(223, 51, 56)`; dark mode: `rgb(245, 84, 89)`
     */
    public var errorColor = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor(red: 245 / 255, green: 84 / 255, blue: 89 / 255, alpha: 1) : UIColor(red: 223 / 255, green: 51 / 255, blue: 56 / 255, alpha: 1)
    
    /**
     * Normal outline color for form inputs.
     * - note: Default: `nil (system default)`
     */
    public var outlineColor = UIColor.systemGray3
    
    /**
     * Outline color for form inputs when focused.
     * - note: Default: `nil (system default)`
     */
    public var outlineColorFocussed: UIColor?
    
    /**
     * Normal outline thickness for form inputs.
     * - note: Default: `nil (system default)`
     */
    public var outlineThickness: NSNumber?
    
    /**
     * Outline thickness for form inputs when focused.
     * - note: Default: `nil (system default)`
     */
    public var outlineThicknessFocussed: NSNumber?
    
    /**
     * Outline corner radius for form input elements.
     * - note: Default: `nil (system default)`
     */
    public var cornerRadius: NSNumber?
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
