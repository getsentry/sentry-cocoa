import ObjectiveC
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentrySubClassFinderTests: XCTestCase {
    
    private class Fixture {
        lazy var runtimeWrapper: SentryTestObjCRuntimeWrapper = {
            let result = SentryTestObjCRuntimeWrapper()
            result.classesNames = { _ in
                return self.testClassesNames
            }
            return result
        }()
        let imageName: String
        let testClassesNames = [NSStringFromClass(FirstViewController.self),
                                NSStringFromClass(SecondViewController.self),
                                NSStringFromClass(ViewControllerNumberThree.self),
                                NSStringFromClass(VCWrongNaming.self),
                                NSStringFromClass(FakeViewController.self)]
        init() {
            if let name = class_getImageName(FirstViewController.self) {
                imageName = String(cString: name, encoding: .utf8) ?? ""
            } else {
                imageName = ""
            }
        }
        
        var sut: SentrySubClassFinder {
            return SentrySubClassFinder(dispatchQueue: SentryDispatchQueueWrapper(), objcRuntimeWrapper: runtimeWrapper)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testActOnSubclassesOfViewController() {
        testActOnSubclassesOfViewController(expected: [FirstViewController.self, SecondViewController.self, ViewControllerNumberThree.self])
    }
    
    func testActOnSubclassesOfViewController_NoViewController() {
        fixture.runtimeWrapper.classesNames = { _ in [] }
        testActOnSubclassesOfViewController(expected: [])
    }
    
    func testActOnSubclassesOfViewController_IgnoreFakeViewController() {
        fixture.runtimeWrapper.classesNames = { _ in [NSStringFromClass(FakeViewController.self)] }
        testActOnSubclassesOfViewController(expected: [])
    }
    
    func testActOnSubclassesOfViewController_IgnoreWrongNaming() {
        fixture.runtimeWrapper.classesNames = { _ in [NSStringFromClass(VCWrongNaming.self)] }
        testActOnSubclassesOfViewController(expected: [])
    }
    
    func testActOnSubclassesOfViewController_WrongImage_NoViewController() {
        fixture.runtimeWrapper.classesNames = nil
        testActOnSubclassesOfViewController(expected: [], imageName: "OtherImage")
    }
  
    func testGettingSublcasses_DoesNotCallInitializer() {
        let sut = SentrySubClassFinder(dispatchQueue: TestSentryDispatchQueueWrapper(), objcRuntimeWrapper: fixture.runtimeWrapper)
        
        var actual: [AnyClass] = []
        sut.actOnSubclassesOfViewController(inImage: fixture.imageName) { subClass in
            actual.append(subClass)
        }
        
        XCTAssertFalse(SentryInitializeForGettingSubclassesCalled.wasCalled())
    }
    
    private func testActOnSubclassesOfViewController(expected: [AnyClass]) {
        testActOnSubclassesOfViewController(expected: expected, imageName: fixture.imageName)
    }
    
    private func testActOnSubclassesOfViewController(expected: [AnyClass], imageName: String) {
        let expect = expectation(description: "")
        
        if expected.isEmpty {
            expect.isInverted = true
        } else {
            expect.expectedFulfillmentCount = expected.count
        }
        
        var actual: [AnyClass] = []
        fixture.sut.actOnSubclassesOfViewController(inImage: imageName) { subClass in
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

class FirstViewController: UIViewController {}
class SecondViewController: UIViewController {}
class ViewControllerNumberThree: UIViewController {}
class VCWrongNaming: UIViewController {}
class FakeViewController {}
#endif
