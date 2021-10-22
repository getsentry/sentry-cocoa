import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class SentryUIViewControllerSwizzlingTests: XCTestCase {
    
    private class Fixture {
        var sut: SentryUIViewControllerSwizziling {
            let options = Options()
            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
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
}

class ViewWithLoadViewController: UIViewController {
    override func loadView() {
        super.loadView()
        // empty on purpose
    }
}

#endif
