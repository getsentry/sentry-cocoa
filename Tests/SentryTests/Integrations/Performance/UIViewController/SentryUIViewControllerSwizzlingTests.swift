import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIViewControllerSwizzlingTests: XCTestCase {
    
    private class Fixture {
        var options: Options {
            let options = Options()
            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
            return options
        }
        
        var sut: SentryUIViewControllerSwizzling {
            return SentryUIViewControllerSwizzling(options: options, dispatchQueue: TestSentryDispatchQueueWrapper())
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
        let controller = UIViewController()
        controller.loadView()
        XCTAssertNil(SentrySDK.span)
    }
    
    func testViewControllerWithoutLoadView_TransactionBoundToScope() {
        let controller = TestViewController()
        controller.loadView()
        XCTAssertNotNil(SentrySDK.span)
    }
    
    func testViewControllerWithLoadView_TransactionBoundToScope() {
        fixture.sut.start()
        let controller = ViewWithLoadViewController()
        
        controller.loadView()
        
        let span = SentrySDK.span
        XCTAssertNotNil(span)
        
        let transactionName = Dynamic(span).name.asString
        let expectedTransactionName = SentryUIViewControllerSanitizer.sanitizeViewControllerName(controller)
        XCTAssertEqual(expectedTransactionName, transactionName)
    }

    func testSwizzle_fromScene() {
        let swizzler = TestSentryUIViewControllerSwizzling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
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
    
    func testSwizzle_fromScene_invalidNotification_NoObject() {
        let swizzler = TestSentryUIViewControllerSwizzling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: nil)
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_ObjectNotAnArray() {
        let swizzler = TestSentryUIViewControllerSwizzling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        let window = UIWindow()
        window.rootViewController = TestViewController()
        let mockWindowScene = ObjectWithWindowsProperty(resultOfWindows: window)
        
        let notification = Notification(name: NSNotification.Name(rawValue: "NotUISceneWillConnectNotification"), object: mockWindowScene)
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)

        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_WrongObjectType() {
        let swizzler = TestSentryUIViewControllerSwizzling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: "Other type of Object")
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromScene_invalidNotification_ObjectWithWrongWindowProperty() {
        let swizzler = TestSentryUIViewControllerSwizzling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: ObjectWithWindowsProperty(resultOfWindows: "Windows property of the wrong type"))
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    func testSwizzle_fromApplication_noDelegate() {
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: MockApplication()))
    }
    
    func testSwizzle_fromApplication_noWindowMethod() {
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: MockApplication(MockApplication.MockApplicationDelegateNoWindow())))
    }
    
    func testSwizzle_fromApplication_noWindow() {
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: MockApplication(MockApplication.MockApplicationDelegate(nil))))
    }
    
    func testSwizzle_fromApplication_noRootViewController_InWindow() {
        XCTAssertFalse(fixture.sut.swizzleRootViewController(from: MockApplication(MockApplication.MockApplicationDelegate(UIWindow()))))
    }
    
    func testSwizzle_fromApplication() {
        let window = UIWindow()
        window.rootViewController = UIViewController()
        let delegate = MockApplication.MockApplicationDelegate(window)
        let app = MockApplication(delegate)
        XCTAssertTrue(fixture.sut.swizzleRootViewController(from: app))
    }
    
}

class MockApplication: NSObject, SentryUIApplication {
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

class ViewWithLoadViewController: UIViewController {
    override func loadView() {
        super.loadView()
        // empty on purpose
    }
}

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
    
    override func swizzleRootViewControllerAndDescendant(_ rootViewController: UIViewController) {
        viewControllers.append(rootViewController)
    }
}

#endif
