#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import SentryTestUtilsDynamic
import XCTest

class SentryUIViewControllerSwizzlingTests: XCTestCase {
    
    private static let mockWindowScene: UIWindowScene = MockUIWindowScene()

    private class Fixture {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let objcRuntimeWrapper = SentryTestObjCRuntimeWrapper()
        let subClassFinder: TestSubClassFinder
        let processInfoWrapper = MockSentryProcessInfo()
        let performanceTracker = SentryUIViewControllerPerformanceTracker()
        var options: Options

        func makeWindow() -> UIWindow {
            UIWindow(windowScene: SentryUIViewControllerSwizzlingTests.mockWindowScene)
        }

        init() {
            subClassFinder = TestSubClassFinder(dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, swizzleClassNameExcludes: [])

            options = Options.noIntegrations()

            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
        }

        var sut: SentryUIViewControllerSwizzling {
            return SentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, performanceTracker: performanceTracker)
        }

        var sutWithDefaultObjCRuntimeWrapper: SentryUIViewControllerSwizzling {
            return SentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: SentryDependencyContainer.sharedInstance().objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, performanceTracker: performanceTracker)
        }

        var testableSut: TestSentryUIViewControllerSwizzling {
            return TestSentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, performanceTracker: performanceTracker)
        }
        
        var delegate: MockApplication.MockApplicationDelegate {
            let window = makeWindow()
            window.rootViewController = UIViewController()
            return MockApplication.MockApplicationDelegate(window)
        }
    }
    
    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentrySDK.start(options: fixture.options)
    }
    
    override func tearDown() {
        super.tearDown()
        // Tests here install the init funnel, which replaces initializers on the base
        // UIViewController. Restore them so the funnel doesn't leak into later suites in the run.
        SentryUIViewControllerSwizzlingHelper.stop()
        clearTestState()
    }
    
    func testExternalViewControllerImage() {
        //Test to ensure ExternalUIViewController exists in an external lib
        //just in case someone changes the settings of the `SentryTestUtils` lib
        let imageName = String(
            cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
            encoding: .utf8)! as NSString
        
        let externalImageName = String(
            cString: class_getImageName(ExternalUIViewController.self)!,
            encoding: .utf8)! as NSString
        
        XCTAssertNotEqual(externalImageName, imageName, "ExternalUIViewController is not in an external library.")
    }

    func testShouldSwizzle_TestViewController() {
        let result = fixture.sut.testShouldSwizzleViewController(TestViewController.self)
        XCTAssertTrue(result)
    }
    
    func testShouldNotSwizzle_NoImageClass() {
        let noImageClass: AnyClass = objc_allocateClassPair(NSObject.self, "NoImageClass", 0)!
        let result = fixture.sut.testShouldSwizzleViewController(noImageClass)

        XCTAssertFalse(result)
    }
    
    func testShouldNotSwizzle_UIViewController() {
        let result = fixture.sut.testShouldSwizzleViewController(UIViewController.self)
        XCTAssertFalse(result)
    }
    
    func testShouldNotSwizzle_UIViewControllerExcludedFromSwizzling() {
        fixture.options.swizzleClassNameExcludes = ["TestViewController"]
        
        XCTAssertFalse(fixture.sut.testShouldSwizzleViewController(TestViewController.self))
    }
    
    func testShouldSwizzle_UIViewControllerNotExcludedFromSwizzling() {
        fixture.options.swizzleClassNameExcludes = ["TestViewController1"]
        
        XCTAssertTrue(fixture.sut.testShouldSwizzleViewController(TestViewController.self))
    }
    
    func testUIViewController_loadView_noTransactionBoundToScope() {
        fixture.sut.start()
        let controller = UIViewController()
        controller.loadView()
        XCTAssertNil(SentrySDK.span)
    }
    
    func testViewControllerWithoutLoadView_TransactionBoundToScope() {
        fixture.sut.start()
        let controller = TestViewController()
        controller.loadView()
        let span = SentrySDK.span
        
        //To finish the transaction we need to finish `initialDisplay` span
        //by calling `viewWillAppear` and reporting a new frame
        controller.viewWillAppear(false)
        //This will call SentryTimeToDisplayTracker.framesTrackerHasNewFrame and finish the span its managing.
        SentryDependencyContainer.sharedInstance().framesTracker.manualReportNewFrame()
        
        XCTAssertNotNil(SentrySDK.span)
        controller.viewDidAppear(false)
        XCTAssertTrue(span?.isFinished == true)
    }
    
    func testViewControllerWithLoadView_TransactionBoundToScope() {
        let d = class_getImageName(type(of: self))!
        fixture.processInfoWrapper.overrides.processPath = String(cString: d)

        fixture.sut.start()
        let controller = ViewWithLoadViewController()
        
        controller.loadView()
        
        let span = SentrySDK.span
        XCTAssertNotNil(span)
        
        let transactionName = Dynamic(span).transactionContext.name.asString
        let expectedTransactionName = SwiftDescriptor.getObjectClassName(controller)
        XCTAssertEqual(expectedTransactionName, transactionName)
    }

    func testSwizzle_fromScene() {
        let swizzler = fixture.testableSut
        let window = fixture.makeWindow()
        window.rootViewController = TestViewController()
        let mockWindowScene = ObjectWithWindowsProperty(resultOfWindows: [window])
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: mockWindowScene)
        swizzler.swizzleRootViewControllerFromSceneDelegateNotification(notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 1)
        XCTAssertTrue(try XCTUnwrap(swizzler.viewControllers.first) is TestViewController)
    }
    
    func testSwizzlingOfExternalLibs() {
        let externalImageName = String(
            cString: class_getImageName(ExternalUIViewController.self)!,
            encoding: .utf8)! as NSString
        fixture.options.add(inAppInclude: externalImageName.lastPathComponent)
        
        let sut = fixture.sut
        sut.start()
        let controller = ExternalUIViewController()
        controller.loadView()
        XCTAssertNotNil(SentrySDK.span)
    }
    
    func testSwizzleInAppIncludes_WithShortenedInAppInclude() throws {
        let imageName = try XCTUnwrap(String(
            cString: class_getImageName(ExternalUIViewController.self)!,
            encoding: .utf8) as? NSString)
        
        let lastPathComponent = String(imageName.lastPathComponent)
        let shortenedLastPathComponent = String(lastPathComponent.prefix(5))
        
        fixture.options.add(inAppInclude: shortenedLastPathComponent)
        
        let sut = fixture.sut
        sut.start()
        let controller = ExternalUIViewController()
        controller.loadView()
        XCTAssertNotNil(SentrySDK.span)
    }
    
    /// Xcode 16 introduces a new flag ENABLE_DEBUG_DYLIB (https://developer.apple.com/documentation/xcode/build-settings-reference#Enable-Debug-Dylib-Support)
    /// If this flag is enabled, debug builds of app and app extension targets on supported platforms and SDKs
    /// will be built with the main binary code in a separate “NAME.debug.dylib”.
    /// This test adds this debug.dylib and checks if it gets swizzled.
    func testSwizzle_DebugDylib_GetsSwizzled() {
        let imageName = String(
            cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
            encoding: .utf8)! as NSString
        
        let debugDylib = "\(imageName).debug.dylib"
        
        let sut = SentryUIViewControllerSwizzling(
            options: fixture.options,
            dispatchQueue: fixture.dispatchQueue,
            objcRuntimeWrapper: fixture.objcRuntimeWrapper,
            subClassFinder: fixture.subClassFinder,
            processInfoWrapper: fixture.processInfoWrapper,
            performanceTracker: fixture.performanceTracker,
            loadedImageNamesProvider: { [debugDylib] }
        )
        sut.start()
        
        let subClassFinderInvocations = fixture.subClassFinder.invocations
        let result = subClassFinderInvocations.invocations.filter { $0.imageName == debugDylib }
            
        XCTAssertEqual(1, result.count)
    }
    
    func testSwizzle_fromScene_invalidNotification_NoObject() {
        let swizzler = fixture.testableSut
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: nil)
        swizzler.swizzleRootViewControllerFromSceneDelegateNotification(notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_ObjectNotAnArray() {
        let swizzler = fixture.testableSut

        let window = fixture.makeWindow()
        window.rootViewController = TestViewController()
        let mockWindowScene = ObjectWithWindowsProperty(resultOfWindows: window)
        
        let notification = Notification(name: NSNotification.Name(rawValue: "NotUISceneWillConnectNotification"), object: mockWindowScene)
        swizzler.swizzleRootViewControllerFromSceneDelegateNotification(notification)

        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_WrongObjectType() {
        let swizzler = fixture.testableSut
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: "Other type of Object")
        swizzler.swizzleRootViewControllerFromSceneDelegateNotification(notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_ObjectWithWrongWindowProperty() {
        let swizzler = fixture.testableSut
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: ObjectWithWindowsProperty(resultOfWindows: "Windows property of the wrong type"))
        swizzler.swizzleRootViewControllerFromSceneDelegateNotification(notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromApplication_noDelegate() {
        XCTAssertFalse(fixture.sut.swizzleRootViewControllerFromUIApplication(MockApplication()))
    }
    
    func testSwizzle_fromApplication_noWindowMethod() {
        let mockApplicationDelegate = MockApplication.MockApplicationDelegateNoWindow()
        let mockApplication = MockApplication(mockApplicationDelegate)
        XCTAssertFalse(fixture.sut.swizzleRootViewControllerFromUIApplication(mockApplication))
    }
    
    func testSwizzle_fromApplication_noWindow() {
        let mockApplicationDelegate = MockApplication.MockApplicationDelegate(nil)
        let mockApplication = MockApplication(mockApplicationDelegate)
        XCTAssertFalse(fixture.sut.swizzleRootViewControllerFromUIApplication(mockApplication))
    }

    func testSwizzle_fromApplication_noRootViewController_InWindow() {
        let mockApplicationDelegate = MockApplication.MockApplicationDelegate(fixture.makeWindow())
        let mockApplication = MockApplication(mockApplicationDelegate)
        XCTAssertFalse(fixture.sut.swizzleRootViewControllerFromUIApplication(mockApplication))
    }
    
    func testSwizzle_fromApplication() {
        // We must keep one strong reference to the delegate. The mock has only a weak.
        let delegate = fixture.delegate
        XCTAssertTrue(fixture.sut.swizzleRootViewControllerFromUIApplication(MockApplication(delegate)))
    }
    
    func testSwizzleUIViewControllersOfClassesInImageOf_ClassIsFromUIKit_NotSwizzled() {
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        
        sut.swizzleUIViewControllersOfClassesInImageOf(UIViewController.self)
        
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count)
    }
    
    func testSwizzleUIViewControllersOfClassesInImageOf_OtherClass_Swizzled() {
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        
        sut.swizzleUIViewControllersOfClassesInImageOf(XCTestCase.self)
        
        XCTAssertEqual(1, fixture.subClassFinder.invocations.count)
    }
    
    func testSwizzleUIViewControllersOfClassesInImageOf_SameClass_OnceSwizzled() {
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        
        sut.swizzleUIViewControllersOfClassesInImageOf(XCTestCase.self)
        sut.swizzleUIViewControllersOfClassesInImageOf(XCTestCase.self)
        
        XCTAssertEqual(1, fixture.subClassFinder.invocations.count)
    }

    func testSwizzlingFromProcessPath_WhenNoAppToFind() {
        let sut = fixture.testableSut
        sut.start()
        XCTAssertTrue(sut.swizzleUIViewControllersOfImageCalled)
    }

    func testStop_whenStartedAndStopped_shouldDeactivateSwizzling() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        sut.stop()

        // -- Assert --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testStop_whenStartedAndStopped_shouldNotTrackViewController() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // Create a view controller and verify it gets tracked
        let controller1 = TestViewController()
        controller1.loadView()
        let span1 = SentrySDK.span
        XCTAssertNotNil(span1, "ViewController should be tracked after start()")

        // Clean up the first transaction
        controller1.viewWillAppear(false)
        SentryDependencyContainer.sharedInstance().framesTracker.manualReportNewFrame()
        controller1.viewDidAppear(false)

        // -- Act --
        sut.stop()

        // -- Assert --
        // Create another view controller and verify it is NOT tracked after stop
        let controller2 = TestViewController()
        controller2.loadView()
        let span2 = SentrySDK.span
        XCTAssertNil(span2, "ViewController should not be tracked after stop()")
    }

    func testStop_whenCalledMultipleTimes_shouldNotCrash() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        sut.stop()
        sut.stop()
        sut.stop()

        // -- Assert --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testStop_whenCalledWithoutStart_shouldNotCrash() {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act & Assert --
        // Should not crash when stop is called without start
        sut.stop()

        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testStop_whenCalled_shouldUnswizzleUIViewController() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // -- Act --
        sut.stop()

        // -- Assert --
        // Verify that swizzling is no longer active
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // Verify that UIViewController loadView doesn't create transactions
        let controller = UIViewController()
        controller.loadView()
        XCTAssertNil(SentrySDK.span)
    }

    // MARK: - Deferred (first-instantiation) swizzling (experimental.enableUIViewControllerInitSwizzling)

    /// With the init funnel active, a view controller handed to the first-instantiation entry point
    /// is swizzled: calling `loadView` afterward creates a transaction.
    func testInitSwizzling_whenViewControllerInstantiated_isSwizzled() {
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.sut
        sut.start()

        sut.testHandleInstantiatedViewController(TestViewController.self)

        let controller = TestViewController()
        controller.loadView()
        XCTAssertNotNil(SentrySDK.span, "An instantiated in-app view controller should be swizzled and tracked.")
    }

    /// The funnel deduplicates by class: a class is only processed once no matter how many instances
    /// are created.
    func testInitSwizzling_whenSameClassInstantiatedTwice_isProcessedOnce() {
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.sut
        sut.start()

        XCTAssertFalse(sut.testHasProcessedViewController(TestViewController.self))
        sut.testHandleInstantiatedViewController(TestViewController.self)
        XCTAssertTrue(sut.testHasProcessedViewController(TestViewController.self))
        // A second call is a no-op (the class is already recorded).
        sut.testHandleInstantiatedViewController(TestViewController.self)
        XCTAssertTrue(sut.testHasProcessedViewController(TestViewController.self))
    }

    /// An excluded class is recorded as processed (so it isn't reconsidered) but is not swizzled.
    func testInitSwizzling_whenClassExcluded_isNotSwizzledButRecorded() {
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        fixture.options.swizzleClassNameExcludes = ["TestViewController"]
        let sut = fixture.sut
        sut.start()

        sut.testHandleInstantiatedViewController(TestViewController.self)

        XCTAssertTrue(sut.testHasProcessedViewController(TestViewController.self), "Excluded classes are still recorded so they aren't reconsidered.")

        let controller = TestViewController()
        controller.loadView()
        XCTAssertNil(SentrySDK.span, "An excluded class must not be swizzled.")
    }

    /// A class that is never instantiated (never handed to the funnel) is never swizzled — the core
    /// GH-8548 guarantee that keeps `@available`-gated classes from being realized below their gate.
    func testInitSwizzling_whenClassNeverInstantiated_isNeverSwizzled() {
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.sut
        sut.start()

        XCTAssertFalse(sut.testHasProcessedViewController(TestViewController.self))

        // We never call the funnel for TestViewController, so it must not be recorded or swizzled.
        // (We can't assert loadView here without instantiating it, which is the point.)
        XCTAssertFalse(sut.testHasProcessedViewController(TestViewController.self))
    }

    /// With the flag off (default), the finder path runs and the init funnel is not installed.
    func testInitSwizzling_whenDisabled_usesFinderPath() {
        XCTAssertFalse(fixture.options.experimental.enableUIViewControllerInitSwizzling)
        let sut = fixture.testableSut
        sut.start()
        // The finder-driven image scan runs (see testSwizzlingFromProcessPath_WhenNoAppToFind).
        XCTAssertTrue(sut.swizzleUIViewControllersOfImageCalled)
    }

    // MARK: - Enabled funnel must never run the subclass-finder path
    //
    // The whole point of the deferred funnel is that the SDK never walks a binary image looking for
    // UIViewController subclasses, because that realizes `@available`-gated classes and crashes below
    // their gate (GH-8152 / GH-8548). Every one of these asserts the finder stays untouched.

    func testInitSwizzling_whenEnabled_doesNotScanImages() {
        // -- Arrange --
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.testableSut

        // -- Act --
        sut.start()

        // -- Assert --
        XCTAssertFalse(sut.swizzleUIViewControllersOfImageCalled, "The funnel must not trigger the image scan.")
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count, "The funnel must never invoke the subclass finder.")
    }

    func testInitSwizzling_whenEnabledAndRootViewControllerFound_doesNotInvokeSubClassFinder() {
        // -- Arrange --
        // The root-hierarchy walk is the one place that also ran the image scan as a fallback, so it
        // is the likeliest way the finder could sneak back in. Uses the real objcRuntimeWrapper so
        // classGetImageName would actually resolve an image if the code asked for one.
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        let window = fixture.makeWindow()
        let rootViewController = TestViewController()
        window.rootViewController = rootViewController

        // -- Act --
        sut.swizzleRootViewControllerAndDescendant(rootViewController)

        // -- Assert --
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count, "The root walk must not fall back to scanning the image when the funnel is enabled.")
    }

    func testInitSwizzling_whenDisabledAndRootViewControllerFound_invokesSubClassFinder() {
        // -- Arrange --
        // Control for the test above: on the eager path the same walk DOES scan the image, which
        // proves the assertion above is about the flag and not a broken fixture.
        XCTAssertFalse(fixture.options.experimental.enableUIViewControllerInitSwizzling)
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        let window = fixture.makeWindow()
        let rootViewController = TestViewController()
        window.rootViewController = rootViewController

        // -- Act --
        sut.swizzleRootViewControllerAndDescendant(rootViewController)

        // -- Assert --
        XCTAssertGreaterThan(fixture.subClassFinder.invocations.count, 0, "The eager path is expected to scan the root view controller's image.")
    }

    /// The root walk must not route through the first-instantiation funnel while the flag is off, so
    /// the eager path keeps behaving exactly as it did before the funnel existed.
    func testInitSwizzling_whenDisabledAndRootViewControllerFound_doesNotUseInstantiationFunnel() {
        // -- Arrange --
        XCTAssertFalse(fixture.options.experimental.enableUIViewControllerInitSwizzling)
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        let window = fixture.makeWindow()
        let rootViewController = TestViewController()
        window.rootViewController = rootViewController

        // -- Act --
        sut.swizzleRootViewControllerAndDescendant(rootViewController)

        // -- Assert --
        XCTAssertFalse(
            sut.testHasProcessedViewController(TestViewController.self),
            "The eager path must not record classes in the funnel's dedup set."
        )
    }

    func testInitSwizzling_whenEnabledAndStartedWithApp_doesNotInvokeSubClassFinder() {
        // -- Arrange --
        // Full start() with a resolvable app delegate + root view controller, i.e. the real launch
        // sequence rather than a single entry point.
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        let delegate = fixture.delegate

        // -- Act --
        sut.start()
        sut.swizzleRootViewControllerFromUIApplication(MockApplication(delegate))

        // -- Assert --
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count, "Neither start() nor the app-delegate walk may invoke the subclass finder.")
    }

    func testInitSwizzling_whenEnabledAndSceneConnects_doesNotInvokeSubClassFinder() {
        // -- Arrange --
        // The scene-notification path is the third route into the root-hierarchy walk.
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        let window = fixture.makeWindow()
        window.rootViewController = TestViewController()
        let mockWindowScene = ObjectWithWindowsProperty(resultOfWindows: [window])
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: mockWindowScene)

        // -- Act --
        sut.swizzleRootViewControllerFromSceneDelegateNotification(notification)

        // -- Assert --
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count, "The scene path must not scan images when the funnel is enabled.")
    }

    func testInitSwizzling_whenEnabled_stillTracksRootViewController() {
        // -- Arrange --
        // Guards against a vacuous version of the assertions above: skipping the finder must not mean
        // skipping instrumentation. The root view controller still has to be swizzled and tracked.
        fixture.options.experimental.enableUIViewControllerInitSwizzling = true
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        let window = fixture.makeWindow()
        let rootViewController = TestViewController()
        window.rootViewController = rootViewController
        sut.start()

        // -- Act --
        sut.swizzleRootViewControllerAndDescendant(rootViewController)

        // -- Assert --
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count)
        rootViewController.loadView()
        XCTAssertNotNil(SentrySDK.span, "The root view controller must still be swizzled via the funnel entry point.")
    }
}

private class MockApplication: NSObject, SentryUIApplication {
    class MockApplicationDelegate: NSObject, UIApplicationDelegate {
        var window: UIWindow?
        
        init(_ window: UIWindow?) {
            self.window = window
        }
    }
    
    class MockApplicationDelegateNoWindow: NSObject, UIApplicationDelegate {
    }
    
    weak var delegate: UIApplicationDelegate?
    
    override init() {
    }
    
    init(_ delegate: UIApplicationDelegate?) {
        self.delegate = delegate
    }
}

// swiftlint:disable prohibited_super_call
class ViewWithLoadViewController: UIViewController {
    override func loadView() {
        // empty on purpose
    }
}
// swiftlint:enable prohibited_super_call

class ObjectWithWindowsProperty: NSObject {
    var resultOfWindows: Any?
    
    override init() {}
    
    init(resultOfWindows: Any?) {
        self.resultOfWindows = resultOfWindows
    }
    
    @objc func windows() -> Any? {
        return resultOfWindows
    }
}

// Not exposed to ObjC: the superclass is an internal Swift type, so generating an @interface for
// this subclass in the test target's generated header wouldn't compile.
private class TestSentryUIViewControllerSwizzling: SentryUIViewControllerSwizzling {
    
    var viewControllers = [UIViewController]()
    var swizzleUIViewControllersOfImageCalled = false
    
    override func swizzleRootViewControllerAndDescendant(_ rootViewController: UIViewController) {
        viewControllers.append(rootViewController)
    }

    override func swizzleUIViewControllers(ofImage imageName: String) {
        swizzleUIViewControllersOfImageCalled = true
        super.swizzleUIViewControllers(ofImage: imageName)
    }
}

private class TestSubClassFinder: SentrySubClassFinder {
    
    var invocations = Invocations<(imageName: String, block: (AnyClass) -> Void)>()
    override func actOnSubclassesOfViewController(inImage imageName: String, block: @escaping (AnyClass) -> Void) {
        invocations.record((imageName, block))
        super.actOnSubclassesOfViewController(inImage: imageName, block: block)
    }
}

#endif
