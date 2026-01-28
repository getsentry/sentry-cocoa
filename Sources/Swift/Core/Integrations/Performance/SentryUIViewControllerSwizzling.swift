@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit

/// Protocol that defines the properties required from UIApplication for swizzling.
/// This allows testing with mock classes instead of relying on UIApplication directly.
@objc protocol SentryUIApplication {
    var delegate: UIApplicationDelegate? { get set }
}

extension UIApplication: SentryUIApplication {}

class SentryUIViewControllerSwizzling {
    private let options: Options
    private let inAppLogic: SentryInAppLogic
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let objcRuntimeWrapper: SentryObjCRuntimeWrapper
    private let subClassFinder: SentrySubClassFinder
    private let imagesActedOnSubclassesOfUIViewControllers: NSMutableSet
    private let processInfoWrapper: SentryProcessInfoSource
    private let binaryImageCache: SentryBinaryImageCache
    private let performanceTracker: SentryUIViewControllerPerformanceTracker

    init(
        options: Options,
        dispatchQueue: SentryDispatchQueueWrapper,
        objcRuntimeWrapper: SentryObjCRuntimeWrapper,
        subClassFinder: SentrySubClassFinder,
        processInfoWrapper: SentryProcessInfoSource,
        binaryImageCache: SentryBinaryImageCache,
        performanceTracker: SentryUIViewControllerPerformanceTracker
    ) {
        self.options = options
        self.inAppLogic = SentryInAppLogic(inAppIncludes: options.inAppIncludes)
        self.dispatchQueue = dispatchQueue
        self.objcRuntimeWrapper = objcRuntimeWrapper
        self.subClassFinder = subClassFinder
        self.imagesActedOnSubclassesOfUIViewControllers = NSMutableSet()
        self.processInfoWrapper = processInfoWrapper
        self.binaryImageCache = binaryImageCache
        self.performanceTracker = performanceTracker
    }

    func start() {
        for inAppInclude in inAppLogic.inAppIncludes {
            let imagePathsToInAppInclude = binaryImageCache.imagePathsFor(inAppInclude: inAppInclude)

            if !imagePathsToInAppInclude.isEmpty {
                for imagePath in imagePathsToInAppInclude {
                    swizzleUIViewControllers(ofImage: imagePath)
                }
            } else {
                SentrySDKLog.warning(
                    "Failed to find the binary image(s) for inAppInclude <\(inAppInclude)> and, therefore can't instrument UIViewControllers in these binaries."
                )
            }
        }

        if let app = findApp() {
            // If an app targets, for example, iOS 13 or lower, the UIKit inits the initial/root view
            // controller before the SentrySDK is initialized. Therefore, we manually call swizzle here
            // not to lose auto-generated transactions for the initial view controller. As we use
            // SentrySwizzleModeOncePerClassAndSuperclasses, we don't have to worry about swizzling
            // twice. We could also use objc_getClassList to lookup sub classes of UIViewController, but
            // the lookup can take around 60ms, which is not acceptable.
            if !swizzleRootViewControllerFromUIApplication(app) {
                SentrySDKLog.debug("Failed to find root UIViewController from UIApplicationDelegate. Trying to use UISceneWillConnectNotification notification.")

                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(swizzleRootViewControllerFromSceneDelegateNotification(_:)),
                    name: UIScene.willConnectNotification,
                    object: nil
                )
            }
        }

        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)
        performanceTracker.inAppLogic = inAppLogic
    }
    
    func stop() {
        SentryUIViewControllerSwizzlingHelper.stop()
    }

    private func findApp() -> SentryUIApplication? {
        guard UIApplication.responds(to: #selector(getter: UIApplication.shared)) else {
            SentrySDKLog.debug("UIApplication doesn't respond to sharedApplication.")
            return nil
        }

        guard let app = UIApplication.perform(#selector(getter: UIApplication.shared))?.takeUnretainedValue() as? UIApplication else {
            SentrySDKLog.debug("UIApplication.sharedApplication is nil.")
            return nil
        }

        return app
    }

    func swizzleUIViewControllersOfClassesInImageOf(_ targetClass: AnyClass?) {
        guard let targetClass else {
            SentrySDKLog.debug("Class is NULL. Skipping swizzling of classes in same image.")
            return
        }

        SentrySDKLog.debug("Class to get the image name: \(targetClass)")

        guard let imageNameAsCharArray = objcRuntimeWrapper.classGetImageName(targetClass) else {
            SentrySDKLog.debug("Wasn't able to get image name of the class: \(targetClass). Skipping swizzling of classes in same image.")
            return
        }

        guard let imageName = String(cString: imageNameAsCharArray, encoding: .utf8), !imageName.isEmpty else {
            SentrySDKLog.debug("Wasn't able to get the app image name of the app delegate class: \(targetClass). Skipping swizzling of classes in same image.")
            return
        }

        swizzleUIViewControllers(ofImage: imageName)
    }

    func swizzleUIViewControllers(ofImage imageName: String) {
        if imageName.contains("UIKitCore") {
            SentrySDKLog.debug("Skipping UIKitCore.")
            return
        }

        if imagesActedOnSubclassesOfUIViewControllers.contains(imageName) {
            SentrySDKLog.debug("Already swizzled UIViewControllers in image: \(imageName).")
            return
        }

        imagesActedOnSubclassesOfUIViewControllers.add(imageName)

        // Swizzle all custom UIViewControllers. Cause loading all classes can take a few milliseconds,
        // the SubClassFinder does this on a background thread, which should be fine because the SDK
        // swizzles the root view controller and its children above. After finding all subclasses of the
        // UIViewController, we swizzles them on the main thread. Swizzling the UIViewControllers on a
        // background thread led to crashes, see GH-1366.

        // Previously, the code intercepted the ViewController initializers with swizzling to swizzle
        // the lifecycle methods. This approach led to UIViewControllers crashing when using a
        // convenience initializer, see GH-1355. The error occurred because our swizzling logic adds the
        // method to swizzle if the class doesn't implement it. It seems like adding an extra
        // initializer causes problems with the rules for initialization in Swift, see
        // https://docs.swift.org/swift-book/LanguageGuide/Initialization.html#ID216.
        subClassFinder.actOnSubclassesOfViewController(inImage: imageName) { [weak self] subClass in
            self?.swizzleViewControllerSubClass(subClass)
        }
    }

    /// If the iOS version is 13 or newer, and the project does not use a custom Window initialization
    /// the app uses a UIScene to manage windows instead of the old AppDelegate.
    /// We wait for the first scene to connect to the app in order to find the rootViewController.
    @objc func swizzleRootViewControllerFromSceneDelegateNotification(_ notification: Notification) {
        guard notification.name == UIScene.willConnectNotification else {
            return
        }

        NotificationCenter.default.removeObserver(
            self,
            name: UIScene.willConnectNotification,
            object: nil
        )

        // The object of a UISceneWillConnectNotification should be a NSWindowScene
        guard let scene = notification.object as? NSObject,
              scene.responds(to: #selector(getter: UIWindowScene.windows)) else {
            SentrySDKLog.debug("Failed to find root UIViewController from UISceneWillConnectNotification. Notification object has no windows property")
            return
        }

        guard let windows = scene.perform(#selector(getter: UIWindowScene.windows))?.takeUnretainedValue() as? [UIWindow] else {
            SentrySDKLog.debug("Failed to find root UIViewController from UISceneWillConnectNotification. Windows is not an array")
            return
        }

        for window in windows {
            if let rootViewController = window.rootViewController {
                swizzleRootViewControllerAndDescendant(rootViewController)
            } else {
                SentrySDKLog.debug("Failed to find root UIViewController from UISceneWillConnectNotification. Window is not a UIWindow class or the rootViewController is nil")
            }
        }
    }

    @discardableResult
    func swizzleRootViewControllerFromUIApplication(_ app: SentryUIApplication) -> Bool {
        guard let delegate = app.delegate else {
            SentrySDKLog.debug("App delegate is nil. Skipping swizzleRootViewControllerFromAppDelegate.")
            return false
        }

        // Check if delegate responds to window, which it doesn't have to.
        guard delegate.responds(to: #selector(getter: UIApplicationDelegate.window)) else {
            SentrySDKLog.debug("UIApplicationDelegate.window is nil. Skipping swizzleRootViewControllerFromAppDelegate.")
            return false
        }

        guard let window = delegate.window as? UIWindow else {
            SentrySDKLog.debug("UIApplicationDelegate.window is nil. Skipping swizzleRootViewControllerFromAppDelegate.")
            return false
        }

        guard let rootViewController = window.rootViewController else {
            SentrySDKLog.debug("UIApplicationDelegate.window.rootViewController is nil. Skipping swizzleRootViewControllerFromAppDelegate.")
            return false
        }

        swizzleRootViewControllerAndDescendant(rootViewController)

        return true
    }

    func swizzleRootViewControllerAndDescendant(_ rootViewController: UIViewController) {
        let allViewControllers = SentryViewController.descendants(of: rootViewController)

        SentrySDKLog.debug("Found \(allViewControllers.count) descendants for RootViewController \(rootViewController)")

        for viewController in allViewControllers {
            let viewControllerClass: AnyClass? = type(of: viewController)
            if let viewControllerClass {
                SentrySDKLog.debug("Calling swizzleRootViewController for \(viewController)")
                swizzleViewControllerSubClass(viewControllerClass)

                // We can't get the image name with the app delegate class for some apps. Therefore, we
                // use the rootViewController and its subclasses as a fallback.  The following method
                // ensures we don't swizzle ViewControllers of UIKit.
                swizzleUIViewControllersOfClassesInImageOf(viewControllerClass)
            } else {
                SentrySDKLog.warning("ViewControllerClass was nil for UIViewController: \(viewController)")
            }
        }
    }

    private func swizzleViewControllerSubClass(_ targetClass: AnyClass) {
        guard shouldSwizzleViewController(targetClass) else {
            SentrySDKLog.debug("Skipping swizzling of class: \(targetClass)")
            return
        }

        SentryUIViewControllerSwizzlingHelper.swizzleViewControllerSubClass(targetClass)
    }

    private func shouldSwizzleViewController(_ targetClass: AnyClass) -> Bool {
        let className = NSStringFromClass(targetClass)

        let shouldExcludeClassFromSwizzling = SentrySwizzleClassNameExclude.shouldExcludeClass(
            className: className,
            swizzleClassNameExcludes: options.swizzleClassNameExcludes
        )

        if shouldExcludeClassFromSwizzling {
            return false
        }

        return inAppLogic.isClassInApp(targetClass)
    }
    
#if SENTRY_TEST || SENTRY_TEST_CI
        // Exposes shouldSwizzle for testing
    func testShouldSwizzleViewController(_ targetClass: AnyClass) -> Bool {
        shouldSwizzleViewController(targetClass)
    }
    #endif
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
