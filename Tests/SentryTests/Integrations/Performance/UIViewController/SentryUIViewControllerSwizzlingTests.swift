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
        
        var sut: SentryUIViewControllerSwizziling {
            return SentryUIViewControllerSwizziling(options: options, dispatchQueue: TestSentryDispatchQueueWrapper())
        }
    }
    
    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
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
        let result = fixture.sut.shouldSwizzleViewController(UIApplication.self)

        XCTAssertFalse(result)
    }
    
    func testShouldNotSwizzle_UIViewController() {
        let result = fixture.sut.shouldSwizzleViewController(UIViewController.self)

        XCTAssertFalse(result)
    }
    
    func testViewControllerWithoutLoadView_NoTransactionBoundToScope() {
        let controller = TestViewController()
        
        controller.loadView()

        XCTAssertNil(SentrySDK.span)
    }
    
    func testViewControllerWithLoadView_TransactionBoundToScope() {
        fixture.sut.start()
        let controller = ViewWithLoadViewController()
        
        controller.loadView()
        
        let span = SentrySDK.span
        XCTAssertNotNil(span)
        
        let transactionName = Dynamic(span).name.asString
        let expectedTransactionName = SentryUIViewControllerSanitizer.sanitizeViewControllerName( controller)
        XCTAssertEqual(expectedTransactionName, transactionName)
    }

    func testSwizzle_fromScene() {
        let swizzler = TestSentryUIViewControllerSwizziling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        let window = UIWindow()
        window.rootViewController = TestViewController()
        let mockWindowScene = ObjectWithWindowsProperty(resultOfWindows: [window])
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: mockWindowScene)
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 1)
        XCTAssertTrue(swizzler.viewControllers[0] is TestViewController)
    }
    
    @available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *)
    func testSwizzle_fromScene_invalidNotification_NoObject() {
        let swizzler = TestSentryUIViewControllerSwizziling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: nil)
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    @available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *)
    func testSwizzle_fromScene_invalidNotification_ObjectNotAnArray() {
        let swizzler = TestSentryUIViewControllerSwizziling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        let window = UIWindow()
        window.rootViewController = TestViewController()
        let mockWindowScene = ObjectWithWindowsProperty(resultOfWindows: window)
        
        let notification = Notification(name: NSNotification.Name(rawValue: "NotUISceneWillConnectNotification"), object: mockWindowScene)
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)

        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    @available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *)
    func testSwizzle_fromScene_invalidNotification_WrongObjectType() {
        let swizzler = TestSentryUIViewControllerSwizziling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: "Other type of Object")
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
    }
    
    @available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *)
    func testSwizzle_fromScene_invalidNotification_ObjectWithWrongWindowProperty() {
        let swizzler = TestSentryUIViewControllerSwizziling(options: fixture.options, dispatchQueue: TestSentryDispatchQueueWrapper())
        let notification = Notification(name: NSNotification.Name(rawValue: "UISceneWillConnectNotification"), object: ObjectWithWindowsProperty(resultOfWindows: "Windows property of the wrong type"))
        swizzler.swizzleRootViewController(fromSceneDelegateNotification: notification)
        
        XCTAssertEqual(swizzler.viewControllers.count, 0)
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

class TestSentryUIViewControllerSwizziling: SentryUIViewControllerSwizziling {
    
    var viewControllers = [UIViewController]()
    
    override func swizzleRootViewControllerAndDescendant(_ rootViewController: UIViewController) {
        viewControllers.append(rootViewController)
    }
}

#endif
