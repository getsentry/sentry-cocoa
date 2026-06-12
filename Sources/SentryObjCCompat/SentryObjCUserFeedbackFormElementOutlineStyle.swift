// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@objc(SentryObjCUserFeedbackFormElementOutlineStyle) public final class SentryObjCUserFeedbackFormElementOutlineStyle: NSObject {
    internal let wrapped: SentryUserFeedbackThemeConfiguration.SentryFormElementOutlineStyle

    internal init(_ wrapped: SentryUserFeedbackThemeConfiguration.SentryFormElementOutlineStyle) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryUserFeedbackThemeConfiguration.SentryFormElementOutlineStyle()
    }

    @objc public init(color: UIColor, cornerRadius: CGFloat, outlineWidth: CGFloat) {
        self.wrapped = SentryUserFeedbackThemeConfiguration.SentryFormElementOutlineStyle(
            color: color,
            cornerRadius: cornerRadius,
            outlineWidth: outlineWidth
        )
    }

    @objc public var color: UIColor {
        get { wrapped.color }
        set { wrapped.color = newValue }
    }

    @objc public var cornerRadius: CGFloat {
        get { wrapped.cornerRadius }
        set { wrapped.cornerRadius = newValue }
    }

    @objc public var outlineWidth: CGFloat {
        get { wrapped.outlineWidth }
        set { wrapped.outlineWidth = newValue }
    }
}
#endif

// swiftlint:enable missing_docs
