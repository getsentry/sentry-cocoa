import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class SentryUIViewControllerSwizzlingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let options = Options()
        let imageName = String(
            cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
            encoding: .utf8)! as NSString
        options.add(inAppInclude: imageName.lastPathComponent)
        SentryUIViewControllerSwizziling.start(with: options, dispatchQueue: TestSentryDispatchQueueWrapper())
    }
    
    override func tearDown() {
        super.tearDown()
        SentryUIViewControllerSwizziling.start(with: Options(), dispatchQueue: TestSentryDispatchQueueWrapper())
    }

    func testShouldSwizzle_TestViewController() {
        let result = SentryUIViewControllerSwizziling.shouldSwizzleViewController(TestViewController.self)

        XCTAssertTrue(result)
    }
    
    func testShouldNotSwizzle_NoImageClass() {
        let result = SentryUIViewControllerSwizziling.shouldSwizzleViewController(UIApplication.self)

        XCTAssertFalse(result)
    }
    
    func testShouldNotSwizzle_UIViewController() {
        let result = SentryUIViewControllerSwizziling.shouldSwizzleViewController(UIViewController.self)

        XCTAssertFalse(result)
    }
    
    func testViewControllerWithoutLoadView_LoadViewNotSwizzled() {
        testLoadViewSwizzle(viewController: TestViewController.self, loadViewSwizzled: false)
    }
    
    func testViewControllerWithLoadView_LoadViewSwizzled() {
        testLoadViewSwizzle(viewController: ViewWithLoadViewController.self, loadViewSwizzled: true)
    }
    
    private func testLoadViewSwizzle(viewController: AnyClass, loadViewSwizzled: Bool) {
        SentryUIViewControllerSwizziling.swizzleViewControllerSubClass(viewController)
        
        let selector = NSSelectorFromString("loadView")
        let viewControllerImp = class_getMethodImplementation(UIViewController.self, selector)
        let classLoadViewImp = class_getMethodImplementation(viewController, selector)
        
        if loadViewSwizzled {
            XCTAssertNotEqual(viewControllerImp, classLoadViewImp)
        } else {
            XCTAssertEqual(viewControllerImp, classLoadViewImp)
        }
        
    }
}

class ViewWithLoadViewController: UIViewController {
    override func loadView() {
        super.loadView()
        // empty on purpose
    }
}

#endif
