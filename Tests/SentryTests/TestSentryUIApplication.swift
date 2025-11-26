#if canImport(UIKit)
@_spi(Private) @testable import Sentry

final class TestSentryUIApplication: SentryApplication {
    func getWindows() -> [UIWindow]? {
        if let windows {
            return windows
        }
        return internal_getWindows()
    }
    
#if (os(iOS) || os(tvOS))
    func getActiveWindowSize() -> CGSize {
        return internal_getActiveWindowSize()
    }
#endif // os(iOS) || os(tvOS)
    
    private var _windows: [UIWindow]?
    private(set) var calledOnMainThread = true
    var windows: [UIWindow]? {
        get {
            calledOnMainThread = Thread.isMainThread
            return _windows
        }
        set {
            calledOnMainThread = Thread.isMainThread
            _windows = newValue
        }
    }
    
    var _relevantViewControllerNames: [String]?
    func relevantViewControllersNames() -> [String]? {
        if let _relevantViewControllerNames {
            return _relevantViewControllerNames
        }
        return UIApplication.shared.relevantViewControllersNames()
    }

    private var _underlyingAppState: UIApplication.State = .active
    var unsafeApplicationState: UIApplication.State {
        get { _underlyingAppState }
        set { _underlyingAppState = newValue }
    }

    var mainThread_isActive: Bool {
        return unsafeApplicationState == .active
    }
    
    var connectedScenes: Set<UIScene> {
        if let scenes = scenes as? [UIScene] {
            return Set(scenes)
        }
        return []
    }

    weak var appDelegate: TestApplicationDelegate?
    var scenes: [Any]?

    var delegate: UIApplicationDelegate? {
        return appDelegate
    }
}

final class TestApplicationDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
}
#endif
