import XCTest

class SentryBreadcrumbTrackerTests: XCTestCase {
    
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        
        scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDK.setCurrentHub(hub)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testSwizzlingStarted_ViewControllerAppears_AddsUILifeCycleBreadcrumb() {
        let sut = SentryBreadcrumbTracker()
        sut.start()
        sut.startSwizzle()
        
        let viewController = UIViewController()
        viewController.viewDidAppear(false)
        
        let crumbs = Dynamic(scope).breadcrumbArray.asArray as? [Breadcrumb]
        
        XCTAssertEqual(2, crumbs?.count)
        
        let lifeCycleCrumb = crumbs?[1]
        XCTAssertEqual("navigation", lifeCycleCrumb?.type)
        XCTAssertEqual("ui.lifecycle", lifeCycleCrumb?.category)
    }
    
#endif
    
}
