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

        // one breadcrumb for starting the tracker, one for the first reachability breadcrumb and one final one for the swizzled viewDidAppear
        guard crumbs.count == 3 else {
            XCTFail("Expected exactly 3 breadcrumbs, got: \(crumbs)")
            return
        }

        let lifeCycleCrumb = crumbs[2]
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
