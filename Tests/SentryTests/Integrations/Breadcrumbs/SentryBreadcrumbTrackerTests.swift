import SentryTestUtils
import XCTest

class SentryBreadcrumbTrackerTests: XCTestCase {
    
    private var delegate: SentryBreadcrumbTestDelegate!
    
    override func setUp() {
        super.setUp()
        delegate = SentryBreadcrumbTestDelegate()
    }
    
    override func tearDown() {
        super.tearDown()
        delegate = nil
        clearTestState()
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testStopRemovesSwizzleSendAction() {
        let sut = SentryBreadcrumbTracker()

        sut.start(with: delegate)
        sut.startSwizzle()
        sut.stop()

        let dict = Dynamic(SentryDependencyContainer.sharedInstance().swizzleWrapper).swizzleSendActionCallbacks().asDictionary
        XCTAssertEqual(0, dict?.count)
    }

    func testSwizzlingStarted_ViewControllerAppears_AddsUILifeCycleBreadcrumb() {
        let scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDK.setCurrentHub(hub)
        
        let sut = SentryBreadcrumbTracker()
        sut.start(with: delegate)
        sut.startSwizzle()

        let viewController = UIViewController()
        _ = UINavigationController(rootViewController: viewController)
        viewController.title = "test title"
        print("delegate: \(String(describing: delegate))")
        print("tracker: \(sut); SentryBreadcrumbTracker.delegate: \(String(describing: Dynamic(sut).delegate.asObject))")
        viewController.viewDidAppear(false)

        let crumbs = delegate.addCrumbInvocations.invocations

        // one breadcrumb for starting the tracker, and a second one for the swizzled viewDidAppear
        guard crumbs.count == 2 else {
            XCTFail("Expected exactly 2 breadcrumbs, got: \(crumbs)")
            return
        }

        let lifeCycleCrumb = crumbs[1]
        XCTAssertEqual("navigation", lifeCycleCrumb.type)
        XCTAssertEqual("ui.lifecycle", lifeCycleCrumb.category)
        XCTAssertEqual("false", lifeCycleCrumb.data?["beingPresented"] as? String)
        XCTAssertEqual("UIViewController", lifeCycleCrumb.data?["screen"] as? String)
        XCTAssertEqual("test title", lifeCycleCrumb.data?["title"] as? String)
        XCTAssertEqual("false", lifeCycleCrumb.data?["beingPresented"] as? String)
        XCTAssertEqual("UINavigationController", lifeCycleCrumb.data?["parentViewController"] as? String)
        
        clearTestState()
    }
#endif

}
