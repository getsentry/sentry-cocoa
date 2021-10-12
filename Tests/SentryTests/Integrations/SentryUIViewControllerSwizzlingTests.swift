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
    
    func testSwizzleSubclassesOfParent() {
        testSwizzleSubclassesOf(Parent.self, expected: [Child1.self, Child2.self, GrandChild1.self, GrandChild2.self])
    }
    
    func testSwizzleSubclassesOfChild1() {
        testSwizzleSubclassesOf(Child1.self, expected: [GrandChild2.self, GrandChild1.self])
    }

    func testSwizzleSubclassesOfChild2() {
        testSwizzleSubclassesOf(Child2.self, expected: [])
    }
    
    private func testSwizzleSubclassesOf(_ type: AnyClass, expected: [AnyClass]) {
        let expect = expectation(description: "")
        
        if expected.isEmpty {
            expect.isInverted = true
        } else {
            expect.expectedFulfillmentCount = expected.count
        }
        
        var actual: [AnyClass] = []
        SentryUIViewControllerSwizziling.swizzleSubclasses(of: type, dispatchQueue: SentryDispatchQueueWrapper()) { subClass in
            XCTAssertTrue(Thread.isMainThread, "Block must be executed on the main thread.")
            actual.append(subClass)
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 1)
        
        let count = actual.filter { element in
            return expected.contains { ex in
                return element == ex
            }
        }.count
        
        XCTAssertEqual(expected.count, count)
    }
}

class ViewWithLoadViewController: UIViewController {
    override func loadView() {
        super.loadView()
        // empty on purpose
    }
}

class Parent: UIViewController {}
class Child1: Parent {}
class Child2: Parent {}
class GrandChild1: Child1 {}
class GrandChild2: Child1 {}

#endif
