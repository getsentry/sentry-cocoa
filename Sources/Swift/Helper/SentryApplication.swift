// swiftlint:disable missing_docs
#if canImport(AppKit) && !SENTRY_NO_UI_FRAMEWORK
import AppKit
#endif
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

@objc @_spi(Private) public protocol SentryApplication {

    var mainThread_isActive: Bool { get }

#if !os(macOS) && !os(watchOS) && !SENTRY_NO_UI_FRAMEWORK

    /**
     * Returns the application state. If called off the main thread, dispatches synchronously
     * to the main thread with a short timeout and returns @c .active as a fallback if the
     * main thread does not respond in time.
     */
    var unsafeApplicationState: UIApplication.State { get }

    /// Gets the current key window
    func getKeyWindow() -> UIWindow?

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
