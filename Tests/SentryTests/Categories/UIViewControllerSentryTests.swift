import XCTest

#if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && SENTRY_USE_UIKIT
class UIViewControllerSentryTests: XCTestCase {

    func testOnlyOneViewController() {
        let viewController = UIViewController()
        XCTAssertEqual([viewController], viewController.sentry_descendantViewControllers)
    }
    
    func testTwoChildViewController() {
        let root = UIViewController()
        
        let child1 = UIViewController()
        root.addChild(child1)
        
        let child2 = UIViewController()
        root.addChild(child2)
        
        XCTAssertEqual(Set([root, child2, child1]), Set(root.sentry_descendantViewControllers))
    }
    
    func testGrandChildViewController() {
        let root = UIViewController()
        
        let child = UIViewController()
        root.addChild(child)
        
        let grandChild1 = UIViewController()
        child.addChild(grandChild1)
        
        let grandChild2 = UIViewController()
        child.addChild(grandChild2)
        
        XCTAssertEqual(Set([root, child, grandChild2, grandChild1]), Set(root.sentry_descendantViewControllers))
    }
}

#endif // (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && SENTRY_USE_UIKIT
