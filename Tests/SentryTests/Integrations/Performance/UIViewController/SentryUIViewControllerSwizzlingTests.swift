#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Sentry
import SentryTestUtils
import SentryTestUtilsDynamic
import XCTest

class SentryUIViewControllerSwizzlingTests: XCTestCase {
    
    private class Fixture {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let objcRuntimeWrapper = SentryTestObjCRuntimeWrapper()
        let subClassFinder: TestSubClassFinder
        let processInfoWrapper = SentryNSProcessInfoWrapper()
        let binaryImageCache: SentryBinaryImageCache
        
        init() {
            subClassFinder = TestSubClassFinder(dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper)
            binaryImageCache = SentryDependencyContainer.sharedInstance().binaryImageCache
        }
         
        var options: Options {
            let options = Options.noIntegrations()
            
            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
            
            let externalImageName = String(
                cString: class_getImageName(ExternalUIViewController.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: externalImageName.lastPathComponent)
            
            return options
        }
        
        var sut: SentryUIViewControllerSwizzling {
            return SentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, binaryImageCache: binaryImageCache)
        }
        
        var sutWithDefaultObjCRuntimeWrapper: SentryUIViewControllerSwizzling {
            return SentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: SentryDefaultObjCRuntimeWrapper.sharedInstance(), subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, binaryImageCache: binaryImageCache)
        }
        
        var testableSut: TestSentryUIViewControllerSwizzling {
            return TestSentryUIViewControllerSwizzling(options: options, dispatchQueue: dispatchQueue, objcRuntimeWrapper: objcRuntimeWrapper, subClassFinder: subClassFinder, processInfoWrapper: processInfoWrapper, binaryImageCache: binaryImageCache)
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
        fixture.processInfoWrapper.setProcessPath(String(cString: d))

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
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        // UIScene is available from iOS 13 and above.
        if #available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *) {
            XCTAssertEqual(swizzler.viewControllers.count, 1)
            XCTAssertTrue(swizzler.viewControllers[0] is TestViewController)
        } else {
            XCTAssertEqual(swizzler.viewControllers.count, 0)
        }
    }
    
    func testSwizzlingOfExternalLibs() {
        let sut = fixture.sut
        sut.start()
        let controller = ExternalUIViewController()
        controller.loadView()
        XCTAssertNotNil(SentrySDK.span)
    }
    
    func testSwizzle_fromScene_invalidNotification_NoObject() {
        let swizzler = fixture.testableSut
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: nil)
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_ObjectNotAnArray() {
        let swizzler = fixture.testableSut
        
        let window = UIWindow()
        window.rootViewController = TestViewController()
        let mockWindowScene = ObjectWithWindowsProperty(resultOfWindows: window)
        
        let notification = Notification(name: NSNotification.Name(rawValue: "NotUISceneWillConnectNotification"), object: mockWindowScene)
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)

        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_WrongObjectType() {
        let swizzler = fixture.testableSut
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: "Other type of Object")
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_ObjectWithWrongWindowProperty() {
        let swizzler = fixture.testableSut
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: ObjectWithWindowsProperty(resultOfWindows: "Windows property of the wrong type"))
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromApplication_noDelegate() {
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: MockApplication()))
    }
    
    func testSwizzle_fromApplication_noWindowMethod() {
        let mockApplicationDelegate = MockApplication.MockApplicationDelegateNoWindow()
        let mockApplication = MockApplication(mockApplicationDelegate)
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: mockApplication))
    }
    
    func testSwizzle_fromApplication_noWindow() {
        let mockApplicationDelegate = MockApplication.MockApplicationDelegate(nil)
        let mockApplication = MockApplication(mockApplicationDelegate)
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: mockApplication))
    }

    func testSwizzle_fromApplication_noRootViewController_InWindow() {
        let mockApplicationDelegate = MockApplication.MockApplicationDelegate(UIWindow())
        let mockApplication = MockApplication(mockApplicationDelegate)
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: mockApplication))
    }
    
    func testSwizzle_fromApplication() {
        // We must keep one strong reference to the delegate. The mock has only a weak.
        let delegate = fixture.delegate
        XCTAssertTrue(fixture.sut.swizzleRootViewController(from: MockApplication(delegate)))
    }
    
    func testSwizzleUIViewControllersOfClassesInImageOf_ClassIsNull() {
        fixture.sut.swizzleUIViewControllersOfClasses(inImageOf: nil)
        
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count)
    }
    
    func testSwizzleUIViewControllersOfClassesInImageOf_ClassIsFromUIKit_NotSwizzled() {
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        
        sut.swizzleUIViewControllersOfClasses(inImageOf: UIViewController.self)
        
        XCTAssertEqual(0, fixture.subClassFinder.invocations.count)
    }
    
    func testSwizzleUIViewControllersOfClassesInImageOf_OtherClass_Swizzled() {
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        
        sut.swizzleUIViewControllersOfClasses(inImageOf: XCTestCase.self)
        
        XCTAssertEqual(1, fixture.subClassFinder.invocations.count)
    }
    
    func testSwizzleUIViewControllersOfClassesInImageOf_SameClass_OnceSwizzled() {
        let sut = fixture.sutWithDefaultObjCRuntimeWrapper
        
        sut.swizzleUIViewControllersOfClasses(inImageOf: XCTestCase.self)
        sut.swizzleUIViewControllersOfClasses(inImageOf: XCTestCase.self)
        
        XCTAssertEqual(1, fixture.subClassFinder.invocations.count)
    }

    func testSwizzlingFromProcessPath_WhenNoAppToFind() {
        let sut = fixture.testableSut
        sut.start()
        XCTAssertTrue(sut.swizzleUIViewControllersOfImageCalled)
    }
}

class MockApplication: NSObject, SentryUIApplicationProtocol {
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

class TestSubClassFinder: SentrySubClassFinder {
    
    var invocations = Invocations<(imageName: String, block: (AnyClass) -> Void)>()
    override func actOnSubclassesOfViewController(inImage imageName: String, block: @escaping (AnyClass) -> Void) {
        invocations.record((imageName, block))
        super.actOnSubclassesOfViewController(inImage: imageName, block: block)
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
