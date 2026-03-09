import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import ObjectiveC
import QuartzCore
import UIKit
#endif

/// Extension providing the Sentry shake detection notification name.
public extension NSNotification.Name {
    /// Notification posted when the device detects a shake gesture on iOS/iPadOS.
    /// On non-iOS platforms this notification is never posted.
    static let SentryShakeDetected = NSNotification.Name("SentryShakeDetected")
}

/// Detects shake gestures by swizzling `UIWindow.motionEnded(_:with:)` on iOS/iPadOS.
/// When a shake gesture is detected, posts a `.SentryShakeDetected` notification.
///
/// Use `enable()` to start detection and `disable()` to stop it.
/// Swizzling is performed at most once regardless of how many times `enable()` is called.
/// On non-iOS platforms (macOS, tvOS, watchOS), these methods are no-ops.
@objc(SentryShakeDetector)
@objcMembers
public final class SentryShakeDetector: NSObject {

    /// The notification name posted on shake, exposed for ObjC consumers.
    /// In Swift, prefer using `.SentryShakeDetected` on `NSNotification.Name` directly.
    @objc public static let shakeDetectedNotification = NSNotification.Name.SentryShakeDetected

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    // Both motionEnded (main thread) and enable/disable (main thread in practice)
    // access this flag. UIKit's motionEnded is always dispatched on the main thread,
    // and the SDK calls enable/disable from main-thread integration lifecycle.
    private static var enabled = false

    private static var swizzled = false
    private static var originalIMP: IMP?
    private static var lastShakeTimestamp: CFTimeInterval = 0
    private static let cooldownSeconds: CFTimeInterval = 1.0
    private static let lock = NSLock()

    /// Enables shake gesture detection. On iOS/iPadOS, swizzles `UIWindow.motionEnded(_:with:)`
    /// the first time it is called, and from then on posts `.SentryShakeDetected`
    /// whenever a shake is detected. No-op on non-iOS platforms.
    public static func enable() {
        lock.lock()
        defer { lock.unlock() }

        if !swizzled {
            let windowClass: AnyClass = UIWindow.self
            let selector = #selector(UIResponder.motionEnded(_:with:))

            guard let inheritedMethod = class_getInstanceMethod(windowClass, selector) else {
                SentrySDKLog.debug("Shake detector: could not find motionEnded(_:with:) on UIWindow")
                return
            }

            let inheritedIMP = method_getImplementation(inheritedMethod)
            let types = method_getTypeEncoding(inheritedMethod)
            class_addMethod(windowClass, selector, inheritedIMP, types)

            guard let ownMethod = class_getInstanceMethod(windowClass, selector) else {
                SentrySDKLog.warning("Shake detector: could not add motionEnded(_:with:) to UIWindow")
                return
            }

            let replacementIMP = imp_implementationWithBlock({ (self: UIWindow, motion: UIEvent.EventSubtype, event: UIEvent?) in
                if SentryShakeDetector.enabled && motion == .motionShake {
                    let now = CACurrentMediaTime()
                    if now - SentryShakeDetector.lastShakeTimestamp > SentryShakeDetector.cooldownSeconds {
                        SentryShakeDetector.lastShakeTimestamp = now
                        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)
                    }
                }

                if let original = SentryShakeDetector.originalIMP {
                    typealias MotionEndedFunc = @convention(c) (Any, Selector, UIEvent.EventSubtype, UIEvent?) -> Void
                    let originalFunc = unsafeBitCast(original, to: MotionEndedFunc.self)
                    originalFunc(self, selector, motion, event)
                }
            } as @convention(block) (UIWindow, UIEvent.EventSubtype, UIEvent?) -> Void)

            originalIMP = method_setImplementation(ownMethod, replacementIMP)
            swizzled = true
            SentrySDKLog.debug("Shake detector: swizzled UIWindow.motionEnded(_:with:)")
        }

        enabled = true
        SentrySDKLog.debug("Shake detector: enabled")
    }

    /// Disables shake gesture detection. Does not un-swizzle `UIWindow`; it only suppresses
    /// the notification so the overhead is negligible. No-op on non-iOS platforms.
    public static func disable() {
        enabled = false
        SentrySDKLog.debug("Shake detector: disabled")
    }
#else
    /// No-op on non-iOS platforms.
    @objc public static func enable() {}
    /// No-op on non-iOS platforms.
    @objc public static func disable() {}
#endif
}
