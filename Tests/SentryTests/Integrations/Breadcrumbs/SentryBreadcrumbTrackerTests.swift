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
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testStopRemovesSwizzleSendAction() {
        let swizzleWrapper = SentrySwizzleWrapper.sharedInstance
        let sut = SentryBreadcrumbTracker(swizzleWrapper: swizzleWrapper)

        sut.start(with: delegate)
        sut.startSwizzle()
        sut.stop()

        let dict = Dynamic(swizzleWrapper).swizzleSendActionCallbacks().asDictionary
        XCTAssertEqual(0, dict?.count)
    }

    func testSwizzlingStarted_ViewControllerAppears_AddsUILifeCycleBreadcrumb() {
        let scope = Scope()
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: scope)
        SentrySDK.setCurrentHub(hub)
        
        let sut = SentryBreadcrumbTracker(swizzleWrapper: SentrySwizzleWrapper.sharedInstance)
        sut.start(with: delegate)
        sut.startSwizzle()

        let viewController = UIViewController()
        _ = UINavigationController(rootViewController: viewController)
        viewController.title = "test title"
        viewController.viewDidAppear(false)

        let crumbs = Dynamic(scope).breadcrumbArray.asArray as? [Breadcrumb]

        XCTAssertEqual(1, crumbs?.count)

        let lifeCycleCrumb = crumbs?[0]
        XCTAssertEqual("navigation", lifeCycleCrumb?.type)
        XCTAssertEqual("ui.lifecycle", lifeCycleCrumb?.category)
        XCTAssertEqual("false", lifeCycleCrumb?.data?["beingPresented"] as? String)
        XCTAssertEqual("UIViewController", lifeCycleCrumb?.data?["screen"] as? String)
        XCTAssertEqual("test title", lifeCycleCrumb?.data?["title"] as? String)
        XCTAssertEqual("false", lifeCycleCrumb?.data?["beingPresented"] as? String)
        XCTAssertEqual("UINavigationController", lifeCycleCrumb?.data?["parentViewController"] as? String)
        
        clearTestState()
    }
    
    func testExtractDataFrom_View() {
        let view = UIView()
        let result = Dynamic(SentryBreadcrumbTracker.self).extractDataFromView(view) as [String: Any?]?
        
        XCTAssertEqual(result?["view"] as? String, String(describing: view))
        XCTAssertNil(result?["title"] as Any?)
        XCTAssertNil(result?["tag"] as Any?)
        XCTAssertNil(result?["accessibilityIdentifier"] as Any?)
    }
    
    func testExtractDataFrom_ViewWith_Tag_accessibilityIdentifier() {
        let view = UIView()
        view.tag = 2
        view.accessibilityIdentifier = "SOME IDENTIFIER"
        
        let result = Dynamic(SentryBreadcrumbTracker.self).extractDataFromView(view) as [String: Any?]?
        
        XCTAssertEqual(result?["view"] as? String, String(describing: view))
        XCTAssertEqual(result?["tag"] as? Int, 2)
        XCTAssertEqual(result?["accessibilityIdentifier"] as? String, "SOME IDENTIFIER")
        XCTAssertNil(result?["title"] as Any?)
    }
    
    func testExtractDataFrom_ButtonWith_Title() {
        let view = UIButton()
        view.setTitle("BUTTON TITLE", for: .normal)
        
        let result = Dynamic(SentryBreadcrumbTracker.self).extractDataFromView(view) as [String: Any?]?
        
        XCTAssertEqual(result?["view"] as? String, String(describing: view))
        XCTAssertEqual(result?["title"] as? String, "BUTTON TITLE")
    }
    
    func testExtractDataFrom_ButtonWithout_Title() {
        let view = UIButton()
        
        let result = Dynamic(SentryBreadcrumbTracker.self).extractDataFromView(view) as [String: Any?]?
        
        XCTAssertEqual(result?["view"] as? String, String(describing: view))
        XCTAssertNil(result?["title"] as Any?)
    }
#endif

}
