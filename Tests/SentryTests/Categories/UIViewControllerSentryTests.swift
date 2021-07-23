import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class UIViewControllerSentryTests: XCTestCase {

    func testOnlyOneViewController() {
        let viewController = UIViewController()
        
        XCTAssertEqual([viewController], viewController.descendantViewControllers)
    }
    
    func testTwoChildViewController() {
        let root = UIViewController()
        
        let child1 = UIViewController()
        root.addChild(child1)
        
        let child2 = UIViewController()
        root.addChild(child2)
        
        XCTAssertEqual([root, child2, child1], root.descendantViewControllers)
    }
    
    func testGrandChildViewController() {
        let root = UIViewController()
        
        let child = UIViewController()
        root.addChild(child)
        
        let grandChild1 = UIViewController()
        child.addChild(grandChild1)
        
        let grandChild2 = UIViewController()
        child.addChild(grandChild2)
        
        XCTAssertEqual([root, child, grandChild2, grandChild1], root.descendantViewControllers)
    }
}

#endif
