// swiftlint:disable missing_docs
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

@objc
@_spi(Private) public final class SwiftDescriptor: NSObject {
    
    @objc
    public static func getObjectClassName(_ object: AnyObject) -> String {
        return String(describing: type(of: object))
    }

    /// UIViewControllers aren't available on watchOS
#if canImport(UIKit) && !os(watchOS) && !SENTRY_NO_UI_FRAMEWORK
    @objc
    public static func getViewControllerClassName(_ object: UIViewController) -> String {
        if let object = object as? SentryUIViewControllerDescriptor {
            return object.sentryName
        }
        return getObjectClassName(object)
    }
#endif

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Builds a description of a view without its frame.
    ///
    /// We build it ourselves instead of using `String(describing:)`, because the default `UIView`
    /// description embeds `frame = (x y; w h)`. Those coordinates can leak which key a user tapped in
    /// custom PIN/passcode views, so we never include the frame.
    @objc
    public static func getSanitizedViewDescription(_ view: UIView) -> String {
        let className = getObjectClassName(view)
        let pointer = Unmanaged.passUnretained(view).toOpaque()
        var attributes: [String] = ["opaque = \(view.isOpaque)"]
        if view.isHidden {
            attributes.append("hidden = true")
        }
        return "<\(className): \(pointer); \(attributes.joined(separator: "; "))>"
    }
#endif

    @objc
    public static func getSwiftErrorDescription(_ error: Error) -> String? {
        return String(describing: error)
    }
}
// swiftlint:enable missing_docs
