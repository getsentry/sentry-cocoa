// swiftlint:disable missing_docs
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)

import UIKit

@objc @_spi(Private) public protocol SentryViewRenderer {
    func render(view: UIView) -> UIImage
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
