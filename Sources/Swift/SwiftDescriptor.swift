import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit
#endif

@objc
class SwiftDescriptor: NSObject {
    
    @objc
    static func getObjectClassName(_ object: AnyObject) -> String { 
        return String(describing: type(of: object))
    }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
    @objc
    static func getViewControllerClassName(_ object: UIViewController) -> String {
        if let object = object as? SentryUIViewControllerDescriptor {
            return object.sentryName
        }
        return getObjectClassName(object)
    }
#endif

    @objc
    static func getSwiftErrorDescription(_ error: Error) -> String? {
        return String(describing: error)
    }
}
