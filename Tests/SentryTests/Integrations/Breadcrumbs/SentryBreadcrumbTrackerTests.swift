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

    func testNetworkConnectivityChangeBreadcrumbs() throws {
        let testReachability = TestSentryReachability()
        
        SentryDependencyContainer.sharedInstance().reachability = testReachability
        
        let sut = SentryBreadcrumbTracker()
        sut.start(with: delegate)
        let states = [SentryConnectivityCellular,
        SentryConnectivityWiFi,
        SentryConnectivityNone,
        SentryConnectivityWiFi,
        SentryConnectivityCellular,
        SentryConnectivityWiFi
        ]
        states.forEach {
            testReachability.setReachabilityState(state: $0)
        }
        sut.stop()
        XCTAssertEqual(delegate.addCrumbInvocations.count, states.count + 1) // 1 breadcrumb for the tracker start
        try states.enumerated().forEach {
            let crumb = delegate.addCrumbInvocations.invocations[$0.offset + 1]
            XCTAssertEqual(crumb.type, "connectivity")
            XCTAssertEqual(crumb.category, "device.connectivity")
            XCTAssertEqual(try XCTUnwrap(crumb.data?["connectivity"] as? String), $0.element)
        }
    }

    func testSwizzlingStarted_ViewControllerAppears_AddsUILifeCycleBreadcrumb() {
        let testReachability = TestSentryReachability()
        
        // We already test the network breadcrumbs in a test above. Using the `TestReachability`
        // makes this test more stable, as using the real implementation sometimes leads to
        // test failure, cause sometimes the dispatch queue responsible for reporting the reachability
        // status takes some time and then there isn't a network breadcrumb available. This test
        // doesn't validate the network breadcrumb anyways.
        SentryDependencyContainer.sharedInstance().reachability = testReachability
        
        let scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDK.setCurrentHub(hub)
        
        let sut = SentryBreadcrumbTracker()
        sut.start(with: delegate)
        sut.startSwizzle()

        // Using UINavigationController as a parent doesn't work on tvOS 17.0
        // for an unknown reason. Therefore, we manually set the parent.
        class ParentUIViewController: UIViewController {
            
        }
        let parentController = ParentUIViewController()
        let viewController = UIViewController()
        parentController.addChild(viewController)
        viewController.title = "test title"
        
        print("delegate: \(String(describing: delegate))")
        print("tracker: \(sut); SentryBreadcrumbTracker.delegate: \(String(describing: Dynamic(sut).delegate.asObject))")
        viewController.viewDidAppear(false)

        let crumbs = delegate.addCrumbInvocations.invocations

        // one breadcrumb for starting the tracker, one for the first reachability breadcrumb and one final one for the swizzled viewDidAppear
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
        XCTAssertEqual("ParentUIViewController", lifeCycleCrumb.data?["parentViewController"] as? String)
        
        clearTestState()
    }
#endif

}
