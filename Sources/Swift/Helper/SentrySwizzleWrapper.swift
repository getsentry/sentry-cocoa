// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@_spi(Private) public typealias SentrySwizzleSendActionCallback = (String, Any?, Any?, UIEvent?) -> Void

@_spi(Private) @objc public class SentrySwizzleWrapper: NSObject {
    
    static var sentrySwizzleSendActionCallbacks = [String: SentrySwizzleSendActionCallback]()
    
    @objc public func swizzleSendAction(_ callback: @escaping SentrySwizzleSendActionCallback, forKey key: String) {
        Self.sentrySwizzleSendActionCallbacks[key] = callback
        SentrySDKLog.debug("Swizzling sendAction for \(key)")

        if Self.sentrySwizzleSendActionCallbacks.count != 1 {
            return
        }

        SentrySwizzleWrapperHelper.swizzle { action, target, sender, event in
            Self.sendActionCalled(action, target: target, sender: sender, event: event)
        }
    }
    
    /// For testing. We want the swizzling block above to call a static function to avoid having a block
    /// reference to an instance of this class.
    static func sendActionCalled(_ action: Selector, target: Any?, sender: Any?, event: UIEvent?) {
        for callback in Self.sentrySwizzleSendActionCallbacks.values {
            callback(String(cString: sel_getName(action)), target, sender, event)
        }
    }

    @objc public func removeSwizzleSendAction(forKey key: String) {
        Self.sentrySwizzleSendActionCallbacks.removeValue(forKey: key)
    }
    
    func removeAllCallbacks() {
        Self.sentrySwizzleSendActionCallbacks.removeAll()
    }
    
    // For test purposes
    static func hasCallbacks() -> Bool {
        return sentrySwizzleSendActionCallbacks.count > 0
    }
}
#endif
// swiftlint:enable missing_docs
