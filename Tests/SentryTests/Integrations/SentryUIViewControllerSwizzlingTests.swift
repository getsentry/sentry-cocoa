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
    
    func testSwizzleSubclassesOfParent() {
        testSwizzleSubclassesOf(Parent.self, expected: [Child1.self, Child2.self, GrandChild1.self, GrandChild2.self])
    }
    
    func testSwizzleSubclassesOfChild1() {
        testSwizzleSubclassesOf(Child1.self, expected: [GrandChild2.self, GrandChild1.self])
    }

    func testSwizzleSubclassesOfChild2() {
        testSwizzleSubclassesOf(Child2.self, expected: [])
    }
    
    func testSwizzleSubclasses_forWrongNumberOfClasses() {
        let expect = expectation(description: "")
        expect.expectedFulfillmentCount = 2
        
        let options = Options()
        let imageName = String(
            cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
            encoding: .utf8)! as NSString
        options.add(inAppInclude: imageName.lastPathComponent)
        let swizzleSubClass = SentryUIViewControllerSwizzlingForTest(options: options, dispatchQueue: TestSentryDispatchQueueWrapper())
        
        swizzleSubClass.swizzleSubclasses(of: Child1.self, dispatchQueue: SentryDispatchQueueWrapper()) { _ in
            XCTAssertTrue(Thread.isMainThread, "Block must be executed on the main thread.")
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 1)
                
        //This means that swizzleSubClass was reset because the number of classes changed.
        XCTAssertEqual(swizzleSubClass.swizzleSubClassLoops, 2)
    }
    
    private func testSwizzleSubclassesOf(_ type: AnyClass, expected: [AnyClass]) {
        let expect = expectation(description: "")
        
        if expected.isEmpty {
            expect.isInverted = true
        } else {
            expect.expectedFulfillmentCount = expected.count
        }
        
        var actual: [AnyClass] = []
        fixture.sut.swizzleSubclasses(of: type, dispatchQueue: SentryDispatchQueueWrapper()) { subClass in
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

class SentryUIViewControllerSwizzlingForTest: SentryUIViewControllerSwizziling {
    
    var swizzleSubClassLoops = 0
    
    override func classListSize() -> Int32 {
        return swizzleSubClassLoops > 1 ? super.classListSize() : 1
    }
    
    override func swizzleSubclasses(of parentClass: AnyClass, dispatchQueue: SentryDispatchQueueWrapper, swizzleBlock block: @escaping (AnyClass) -> Void) {
        swizzleSubClassLoops += 1
        super.swizzleSubclasses(of: parentClass, dispatchQueue: dispatchQueue, swizzleBlock: block)
    }
}

class Parent: UIViewController {}
class Child1: Parent {}
class Child2: Parent {}
class GrandChild1: Child1 {}
class GrandChild2: Child1 {}

#endif
