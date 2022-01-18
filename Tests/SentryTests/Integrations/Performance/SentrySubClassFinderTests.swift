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

    func testActOnSubclassesOfParent_ReturnsChildren() {
        testActOnSubclassesOf(Parent.self, expected: [Child1.self, Child2.self, GrandChild1.self, GrandChild2.self])
    }
    
    func testActOnSubclassesOfChild1_ReturnsChildren() {
        testActOnSubclassesOf(Child1.self, expected: [GrandChild2.self, GrandChild1.self])
    }

    func testActOnSubclassesOfChild2_ReturnsChildren() {
        testActOnSubclassesOf(Child2.self, expected: [])
    }
    
    func testActOnSubclassesOfChild2_WhenNewClassesRegistered_ReturnNoChildren() {
        fixture.runtimeWrapper.beforeGetClassList = {
            SentryClassRegistrator.registerClass(SentryId().sentryIdString)
        }
        testActOnSubclassesOf(Child1.self, expected: [])
        XCTAssertEqual(0, fixture.runtimeWrapper.iterateClassesInvocations)
    }
    
    func testActOnSubclassesOfChild2_WhenNewClassOnlyOnceRegistered_ReturnsChildren() {
        var invocations = 0
        fixture.runtimeWrapper.beforeGetClassList = {
            if invocations == 1 {
                SentryClassRegistrator.registerClass(SentryId().sentryIdString)
            }
            invocations += 1
        }
        testActOnSubclassesOf(Child1.self, expected: [GrandChild2.self, GrandChild1.self])
    }
    
    func testActOnSubclasses_SecondClassListReturns0_NoChildrenFound() {
        var invocations = -1
        fixture.runtimeWrapper.numClasses = { numClasses in
            invocations += 1
            return invocations > 0 ? 0 : numClasses
        }
        
        testActOnSubclassesOf(Child1.self, expected: [])
    }
    
    func testActOnSubclasses_SecondClassListReturnsOneLess_ReturnsChildren() {
        var invocations = -1
        fixture.runtimeWrapper.numClasses = { numClasses in
            invocations += 1
            return invocations > 0 ? numClasses - 1 : numClasses
        }
        
        testActOnSubclassesOf(Child1.self, expected: [GrandChild2.self, GrandChild1.self])
    }
    
    func testActOnSubclasses_ClassListKeepsReturnsOneLess_ReturnsNoChildren() {
        var invocations = -1
        fixture.runtimeWrapper.numClasses = { numClasses in
            invocations += 1
            return numClasses - Int32(invocations)
        }
        
        testActOnSubclassesOf(Child1.self, expected: [])
        XCTAssertEqual(0, fixture.runtimeWrapper.iterateClassesInvocations)
    }
    
    func testActOnSubclasses_NoClassesFound_ReturnsNoChildren() {
        fixture.runtimeWrapper.numClasses = { _ in 0 }
        
        testActOnSubclassesOf(Child1.self, expected: [])
    }
    
    func testGettingSublcasses_DoesNotCallInitializer() {
        let sut = SentrySubClassFinder(dispatchQueue: TestSentryDispatchQueueWrapper(), objcRuntimeWrapper: fixture.runtimeWrapper)
        
        var actual: [AnyClass] = []
        sut.act(onSubclassesOf: NSObject.self) { subClass in
            actual.append(subClass)
        }
        
        XCTAssertFalse(SentryInitializeForGettingSubclassesCalled.wasCalled())
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
