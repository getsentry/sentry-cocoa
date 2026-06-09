// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@objc(SentryObjCUserFeedbackThemeConfiguration) public final class SentryObjCUserFeedbackThemeConfiguration: NSObject {
    internal let wrapped: SentryUserFeedbackThemeConfiguration

    internal init(_ wrapped: SentryUserFeedbackThemeConfiguration) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryUserFeedbackThemeConfiguration()
    }

    @objc public var fontFamily: String? {
        get { wrapped.fontFamily }
        set { wrapped.fontFamily = newValue }
    }

    @objc public var foreground: UIColor {
        get { wrapped.foreground }
        set { wrapped.foreground = newValue }
    }

    @objc public var background: UIColor {
        get { wrapped.background }
        set { wrapped.background = newValue }
    }

    @objc public var submitForeground: UIColor {
        get { wrapped.submitForeground }
        set { wrapped.submitForeground = newValue }
    }

    @objc public var submitBackground: UIColor {
        get { wrapped.submitBackground }
        set { wrapped.submitBackground = newValue }
    }

    @objc public var buttonForeground: UIColor {
        get { wrapped.buttonForeground }
        set { wrapped.buttonForeground = newValue }
    }

    @objc public var buttonBackground: UIColor {
        get { wrapped.buttonBackground }
        set { wrapped.buttonBackground = newValue }
    }

    @objc public var errorColor: UIColor {
        get { wrapped.errorColor }
        set { wrapped.errorColor = newValue }
    }

    @objc public var outlineStyle: SentryObjCUserFeedbackFormElementOutlineStyle {
        get { SentryObjCUserFeedbackFormElementOutlineStyle(wrapped.outlineStyle) }
        set { wrapped.outlineStyle = newValue.wrapped }
    }

    @objc public var inputBackground: UIColor {
        get { wrapped.inputBackground }
        set { wrapped.inputBackground = newValue }
    }

    @objc public var inputForeground: UIColor {
        get { wrapped.inputForeground }
        set { wrapped.inputForeground = newValue }
    }
}
#endif

// swiftlint:enable missing_docs
