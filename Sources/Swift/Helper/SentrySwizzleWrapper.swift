@_implementationOnly import _SentryPrivate
import Foundation

#if canImport(UIKit)
import UIKit

public typealias SentrySwizzleSendActionCallback = (_ actionName: String, _ target: Any?, _ sender: Any?, _ event: UIEvent?) -> Void

/**
 * A wrapper around swizzling for testability and to only swizzle once when multiple implementations
 * need to be called for the same swizzled method.
 */
@objc public class SentrySwizzleWrapper: NSObject {

    private static var sentrySwizzleSendActionCallbacks: [String:  SentrySwizzleSendActionCallback] = [:]

    override init() {
        super.init()
    }
    
    @objc
    public func swizzleSendAction(_ callback: @escaping SentrySwizzleSendActionCallback, forKey key: String) {
        // We need to make a copy of the block to avoid ARC of autoreleasing it.
        SentrySwizzleWrapper.sentrySwizzleSendActionCallbacks[key] = callback
        SentrySDKLog.debug("Swizzling sendAction for \(key)")
        
        if SentrySwizzleWrapper.sentrySwizzleSendActionCallbacks.count != 1 {
            return
        }
        
        // Static pointer for swizzle key - equivalent to Objective-C static const void *
        struct SwizzleKey {
            static let swizzleSendActionKey = "swizzleSendActionKey"
        }
        
        let selector = NSSelectorFromString("sendAction:to:from:forEvent:")
        
        // Convert the macro-based swizzling to direct API call
        SentrySwizzle.swizzleInstanceMethod(
            selector,
            in: UIApplication.self,
            newImpFactory: { swizzleInfo in
                // This block will be used as the new implementation
                return { (_ self: UIApplication, action: Selector, target: Any?, sender: Any?, event: UIEvent?) -> Bool in
                    SentrySwizzleWrapper.sendActionCalled(action, target: target, sender: sender, event: event)
                    
                    // Call original implementation
                    let originalImp = swizzleInfo.getOriginalImplementation()
                    typealias OriginalMethodSignature = @convention(c) (UIApplication, Selector, Selector, Any?, Any?, UIEvent?) -> Bool
                    let originalMethod = unsafeBitCast(originalImp, to: OriginalMethodSignature.self)
                    return originalMethod(_self, selector, action, target, sender, event)
                } as @convention(block) (UIApplication, Selector, Any?, Any?, UIEvent?) -> Bool
            },
            mode: .oncePerClassAndSuperclasses,
            key: SwizzleKey.swizzleSendActionKey.withUnsafeBytes { $0.baseAddress }
        )
    }
    
    @objc
    public func removeSwizzleSendActionForKey(_ key: String) {
        SentrySwizzleWrapper.sentrySwizzleSendActionCallbacks.removeValue(forKey: key)
    }
    
    /**
     * For testing. We want the swizzling block above to call a static function to avoid having a block
     * reference to an instance of this class.
     */
    @objc
    public static func sendActionCalled(_ action: Selector, target: Any?, sender: Any?, event: UIEvent?) {
        for (_ , callback) in SentrySwizzleWrapper.sentrySwizzleSendActionCallbacks {
            let actionName = String(format: "%s", sel_getName(action))
            callback(actionName, target, sender, event)
        }
    }
    
    /**
     * For testing.
     */
    @objc
    public func swizzleSendActionCallbacks() -> NSDictionary {
        return NSDictionary(dictionary: SentrySwizzleWrapper.sentrySwizzleSendActionCallbacks)
    }
    
    @objc
    public func removeAllCallbacks() {
        SentrySwizzleWrapper.sentrySwizzleSendActionCallbacks.removeAll()
    }
    
    // For test purpose
    @objc
    public static func hasCallbacks() -> Bool {
        return SentrySwizzleWrapper.sentrySwizzleSendActionCallbacks.count > 0
    }
}

#endif // SENTRY_HAS_UIKIT
