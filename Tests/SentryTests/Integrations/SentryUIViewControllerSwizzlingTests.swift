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
        clearTestState()
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
    
    func testViewControllerWithoutLoadView_NoTransactionBoundToScope() {
        let controller = TestViewController()
        
        controller.loadView()

        XCTAssertNil(SentrySDK.span)
    }
    
    func testViewControllerWithLoadView_TransactionBoundToScope() {
        let controller = ViewWithLoadViewController()
        
        controller.loadView()
        
        let span = SentrySDK.span
        XCTAssertNotNil(span)
        
        let transactionName = Dynamic(span).name.asString
        let expectedTransactionName = SentryUIViewControllerSanitizer.sanitizeViewControllerName( controller)
        XCTAssertEqual(expectedTransactionName, transactionName)
    }

}

class ViewWithLoadViewController: UIViewController {
    override func loadView() {
        super.loadView()
        // empty on purpose
    }
}

#endif
