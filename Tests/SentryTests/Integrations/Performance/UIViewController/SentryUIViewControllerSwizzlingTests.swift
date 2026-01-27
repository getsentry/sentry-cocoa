#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import SentryTestUtilsDynamic
import XCTest

class SentryUIViewControllerSwizzlingTests: XCTestCase {
    
    private class Fixture {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let objcRuntimeWrapper = SentryTestObjCRuntimeWrapper()
        let subClassFinder: TestSubClassFinder
        let processInfoWrapper = MockSentryProcessInfo()
        let binaryImageCache: SentryBinaryImageCache
        let performanceTracker = SentryUIViewControllerPerformanceTracker()
        var options: Options

        init() {
            subClassFinder = TestSubClassFinder(dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, swizzleClassNameExcludes: [])
            binaryImageCache = SentryDependencyContainer.sharedInstance().binaryImageCache

            options = Options.noIntegrations()

            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
        }

        var sut: SentryUIViewControllerSwizzling {
            return SentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, binaryImageCache: binaryImageCache, performanceTracker: performanceTracker)
        }

        var sutWithDefaultObjCRuntimeWrapper: SentryUIViewControllerSwizzling {
            return SentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: SentryDependencyContainer.sharedInstance().objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, binaryImageCache: binaryImageCache, performanceTracker: performanceTracker)
        }

        var testableSut: TestSentryUIViewControllerSwizzling {
            return TestSentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, binaryImageCache: binaryImageCache, performanceTracker: performanceTracker)
        }
        
        var delegate: MockApplication.MockApplicationDelegate {
            let window = UIWindow()
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
        let result = fixture.sut.shouldSwizzleViewController(TestViewController.self)
        XCTAssertTrue(result)
    }
    
    func testShouldNotSwizzle_NoImageClass() {
        let noImageClass: AnyClass = objc_allocateClassPair(NSObject.self, "NoImageClass", 0)!
        let result = fixture.sut.shouldSwizzleViewController(noImageClass)

        XCTAssertFalse(result)
    }
    
    func testShouldNotSwizzle_UIViewController() {
        let result = fixture.sut.shouldSwizzleViewController(UIViewController.self)
        XCTAssertFalse(result)
    }
    
    func testShouldNotSwizzle_UIViewControllerExcludedFromSwizzling() {
        fixture.options.swizzleClassNameExcludes = ["TestViewController"]
        
        XCTAssertFalse(fixture.sut.shouldSwizzleViewController(TestViewController.self))
    }
    
    func testShouldSwizzle_UIViewControllerNotExcludedFromSwizzling() {
        fixture.options.swizzleClassNameExcludes = ["TestViewController1"]
        
        XCTAssertTrue(fixture.sut.shouldSwizzleViewController(TestViewController.self))
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
        Dynamic(SentryDependencyContainer.sharedInstance().framesTracker).reportNewFrame()
        
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
        let window = UIWindow()
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
        
        let image = createCrashBinaryImage(0, name: debugDylib)
        SentryDependencyContainer.sharedInstance().binaryImageCache.start(false)
        SentryDependencyContainer.sharedInstance().binaryImageCache.binaryImageAdded(imageName: image.name,
                                                                                     vmAddress: image.vmAddress,
                                                                                     address: image.address,
                                                                                     size: image.size,
                                                                                     uuid: image.uuid)
        
        let sut = fixture.sut
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
        
        let window = UIWindow()
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
        let mockApplicationDelegate = MockApplication.MockApplicationDelegate(UIWindow())
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
        Dynamic(SentryDependencyContainer.sharedInstance().framesTracker).reportNewFrame()
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

class TestSentryUIViewControllerSwizzling: SentryUIViewControllerSwizzling {
    
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
