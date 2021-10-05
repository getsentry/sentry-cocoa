import Sentry
import XCTest

class SentrySubClassFinderTests: XCTestCase {

    func testGetSubClassesOfParent() {
        
        let actual = SentrySubClassFinder.classGetSubclasses(Parent.self)
        let expected = [Child1.self, Child2.self, GrandChild1.self, GrandChild2.self]
        
        assert(expected, actual)
    }
    
    func testGetSubClassesOfChild1() {
        
        let actual = SentrySubClassFinder.classGetSubclasses(Child1.self)
        let expected = [GrandChild2.self, GrandChild1.self]
        
        assert(expected, actual)
    }
    
    func testGetSubClassesOfChild2() {
        
        let actual = SentrySubClassFinder.classGetSubclasses(Child2.self)
        
        XCTAssertEqual(0, actual.count)
    }
    
    private func assert(_ expected: [AnyClass], _ actual: [AnyClass]) {
        
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
