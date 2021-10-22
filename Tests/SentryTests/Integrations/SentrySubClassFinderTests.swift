import XCTest

class SentrySubClassFinderTests: XCTestCase {

    private class Fixture {
        let runtimeWrapper = SentryTestObjCRuntimeWrapper()
        
        var sut: SentrySubClassFinder {
            return SentrySubClassFinder(dispatchQueue: SentryDispatchQueueWrapper(), objcRuntimeWrapper: runtimeWrapper)
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

    func testActOnSubclassesOfParent_ReturnsChildren() {
        testActOnSubclassesOf(Parent.self, expected: [Child1.self, Child2.self, GrandChild1.self, GrandChild2.self])
    }
    
    func testActOnSubclassesOfChild1_ReturnsChildren() {
        testActOnSubclassesOf(Child1.self, expected: [GrandChild2.self, GrandChild1.self])
    }

    func testActOnSubclassesOfChild2_ReturnsChildren() {
        testActOnSubclassesOf(Child2.self, expected: [])
    }
    
    func testActOnSubclassesOfChild2_WhenNewClassRegistered_ReturnsChildren() {
        fixture.runtimeWrapper.beforeGetClassList = {
            SentryClassGenerator.registerClass(SentryId().sentryIdString)
        }
        testActOnSubclassesOf(Child1.self, expected: [GrandChild2.self, GrandChild1.self])
    }
    
    func testActOnSubclasses_SecondClassListReturns0_NoChildrenFound() {
        var invocations = -1
        fixture.runtimeWrapper.numClasses = { numClasses in
            invocations += 1
            if invocations > 0 {
                return 0
            }
            return numClasses
        }
        
        testActOnSubclassesOf(Child1.self, expected: [])
    }
    
    func testActOnSubclasses_NoClassesFound_ReturnsNoChildren() {
        fixture.runtimeWrapper.numClasses = { _ in
            return 0
        }
        
        testActOnSubclassesOf(Child1.self, expected: [])
    }
    
    func testGettingSublcasses_DoesNotCallInitializer() {
        let sut = SentrySubClassFinder(dispatchQueue: TestSentryDispatchQueueWrapper(), objcRuntimeWrapper: fixture.runtimeWrapper)
        
        var actual: [AnyClass] = []
        sut.act(onSubclassesOf: NSObject.self) { subClass in
            actual.append(subClass)
        }
        
        XCTAssertFalse(SentryInitializeNotCalled.wasInitializerCalled())
    }
    
    private func testActOnSubclassesOf(_ type: AnyClass, expected: [AnyClass]) {
        let expect = expectation(description: "")
        
        if expected.isEmpty {
            expect.isInverted = true
        } else {
            expect.expectedFulfillmentCount = expected.count
        }
        
        var actual: [AnyClass] = []
        fixture.sut.act(onSubclassesOf: type) { subClass in
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

class Parent {}
class Child1: Parent {}
class Child2: Parent {}
class GrandChild1: Child1 {}
class GrandChild2: Child1 {}
