// swiftlint:disable missing_docs
#if canImport(AppKit) && !SENTRY_NO_UI_FRAMEWORK
import AppKit
#endif
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

@objc @_spi(Private) public protocol SentryApplication {
    
    // This can only be accessed on the main thread
    var mainThread_isActive: Bool { get }

    #if !os(macOS) && !os(watchOS) && !SENTRY_NO_UI_FRAMEWORK
    
    /**
     * Returns the application state available at @c UIApplication.sharedApplication.applicationState
     * Must be called on the main thread.
     */
    var unsafeApplicationState: UIApplication.State { get }

/**
 * All windows connected to scenes.
 */
    func getWindows() -> [UIWindow]?
    
#if (os(iOS) || os(tvOS))
    func getActiveWindowSize() -> CGSize
#endif // os(iOS) || os(tvOS)
    
    var connectedScenes: Set<UIScene> { get }

    var delegate: UIApplicationDelegate? { get }

/**
 * Use @c [SentryUIApplication relevantViewControllers] and convert the
 * result to a string array with the class name of each view controller.
 */
    func relevantViewControllersNames() -> [String]?
    #endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
}
// swiftlint:enable missing_docs
