@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryViewHierarchyProviderTests: XCTestCase {
    private class Fixture {
        let uiApplication = TestSentryUIApplication()

        var sut: SentryViewHierarchyProvider {
            return SentryViewHierarchyProvider(dispatchQueueWrapper: SentryDispatchQueueWrapper(), sentryUIApplication: uiApplication)
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()

        fixture = Fixture()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        /**
         * This test is making iOS 13 simulator hang in GH workflow,
         * thats why we need to check for iOS 13 or later.
         * By testing this in the other versions of iOS we guarantee the behavior
         * mean while, running an iOS 12 sample with Saucelabs ensures this feature
         * is not crashing the app.
         */
        guard #available(iOS 13, *) else {
            throw XCTSkip("Skipping for iOS < 13")
        }
    }

    func test_Multiple_Window() {
        let firstWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let secondWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))

        fixture.uiApplication.windows = [firstWindow, secondWindow]

        guard let descriptions = self.fixture.sut.appViewHierarchy() else {
            XCTFail("Could not serialize view hierarchy")
            return
        }

        let object = try? JSONSerialization.jsonObject(with: descriptions) as? NSDictionary
        let windows = object?["windows"] as? NSArray
        XCTAssertNotNil(windows)
        XCTAssertEqual(windows?.count, 2)
    }

    func test_ViewHierarchy_fetch() {
        var window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        window.accessibilityIdentifier = "WindowId"

        fixture.uiApplication.windows = [window]
        guard let data = self.fixture.sut.appViewHierarchy()
        else {
            XCTFail("Could not serialize view hierarchy")
            return
        }
        var descriptions = String(data: data, encoding: .utf8) ?? ""

        XCTAssertEqual(descriptions, "{\"rendering_system\":\"UIKIT\",\"windows\":[{\"type\":\"UIWindow\",\"identifier\":\"WindowId\",\"width\":10,\"height\":10,\"x\":0,\"y\":0,\"alpha\":1,\"visible\":false,\"children\":[]}]}")

        window = UIWindow(frame: CGRect(x: 1, y: 2, width: 20, height: 30))
        window.accessibilityIdentifier = "IdWindow"

        fixture.uiApplication.windows = [window]

        guard let data = self.fixture.sut.appViewHierarchy()
        else {
            XCTFail("Could not serialize view hierarchy")
            return
        }
        descriptions = String(data: data, encoding: .utf8) ?? ""

        XCTAssertEqual(descriptions, "{\"rendering_system\":\"UIKIT\",\"windows\":[{\"type\":\"UIWindow\",\"identifier\":\"IdWindow\",\"width\":20,\"height\":30,\"x\":1,\"y\":2,\"alpha\":1,\"visible\":false,\"children\":[]}]}")
    }

    func test_Window_with_children() {
        let firstWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let childView = UIView(frame: CGRect(x: 1, y: 1, width: 8, height: 8))
        let secondChildView = UIView(frame: CGRect(x: 2, y: 2, width: 6, height: 6))

        firstWindow.addSubview(childView)
        firstWindow.addSubview(secondChildView)

        fixture.uiApplication.windows = [firstWindow]

        guard let descriptions = self.fixture.sut.appViewHierarchy()
        else {
            XCTFail("Could not serialize view hierarchy")
            return
        }

        let object = try? JSONSerialization.jsonObject(with: descriptions) as? NSDictionary
        let window = (object?["windows"] as? NSArray)?.firstObject as? NSDictionary
        let children = window?["children"] as? NSArray

        let firstChild = children?.firstObject as? NSDictionary

        XCTAssertEqual(children?.count, 2)
        XCTAssertEqual(firstChild?["type"] as? String, "UIView")
    }

    func test_ViewHierarchy_with_ViewController() {
        let firstWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let viewController = UIViewController()
        firstWindow.rootViewController = viewController
        firstWindow.addSubview(viewController.view)

        fixture.uiApplication.windows = [firstWindow]

        guard let descriptions = self.fixture.sut.appViewHierarchy()
        else {
            XCTFail("Could not serialize view hierarchy")
            return
        }

        let object = try? JSONSerialization.jsonObject(with: descriptions) as? NSDictionary
        let window = (object?["windows"] as? NSArray)?.firstObject as? NSDictionary
        let children = window?["children"] as? NSArray

        let firstChild = children?.firstObject as? NSDictionary

        XCTAssertEqual(firstChild?["view_controller"] as? String, "UIViewController")
    }

    func test_ViewHierarchy_save() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        window.accessibilityIdentifier = "WindowId"

        fixture.uiApplication.windows = [window]

        let path = FileManager.default.temporaryDirectory.appendingPathComponent("view.json").path
        self.fixture.sut.saveViewHierarchy(path)

        let descriptions = (try? String(contentsOfFile: path)) ?? ""

        XCTAssertEqual(descriptions, "{\"rendering_system\":\"UIKIT\",\"windows\":[{\"type\":\"UIWindow\",\"identifier\":\"WindowId\",\"width\":10,\"height\":10,\"x\":0,\"y\":0,\"alpha\":1,\"visible\":false,\"children\":[]}]}")
    }
    
    func test_ViewHierarchy_save_noIdentifier() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        window.accessibilityIdentifier = "WindowId"

        fixture.uiApplication.windows = [window]

        let path = FileManager.default.temporaryDirectory.appendingPathComponent("view.json").path
        let sut = self.fixture.sut
        sut.reportAccessibilityIdentifier = false
        sut.saveViewHierarchy(path)

        let descriptions = try XCTUnwrap(String(contentsOfFile: path))

        XCTAssertEqual(descriptions, "{\"rendering_system\":\"UIKIT\",\"windows\":[{\"type\":\"UIWindow\",\"width\":10,\"height\":10,\"x\":0,\"y\":0,\"alpha\":1,\"visible\":false,\"children\":[]}]}")
    }

    func test_invalidFilePath() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        window.accessibilityIdentifier = "WindowId"

        fixture.uiApplication.windows = [window]

        XCTAssertFalse(self.fixture.sut.saveViewHierarchy(""))
    }

    func test_invalidSerialization() {
        let sut = TestSentryViewHierarchyProvider(dispatchQueueWrapper: SentryDispatchQueueWrapper(), sentryUIApplication: fixture.uiApplication)
        sut.viewHierarchyResult = -1
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        window.accessibilityIdentifier = "WindowId"

        fixture.uiApplication.windows = [window]
        let result = sut.appViewHierarchy()
        XCTAssertNil(result)
    }

    func test_appViewHierarchyFromBackgroundTest() {
        let sut = TestSentryViewHierarchyProvider(dispatchQueueWrapper: SentryDispatchQueueWrapper(), sentryUIApplication: fixture.uiApplication)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        fixture.uiApplication.windows = [window]

        let ex = expectation(description: "Running on Main Thread")
        sut.processViewHierarchyCallback = {
            ex.fulfill()
            XCTAssertTrue(Thread.isMainThread)
        }

        let dispatch = DispatchQueue(label: "background")
        dispatch.async {
            let _ = sut.appViewHierarchyFromMainThread()
        }

        wait(for: [ex], timeout: 5)
    }

    func test_appViewHierarchy_usesMainThread() {
        let sut = TestSentryViewHierarchyProvider(dispatchQueueWrapper: SentryDispatchQueueWrapper(), sentryUIApplication: fixture.uiApplication)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        fixture.uiApplication.windows = [window]

        let ex = expectation(description: "Running on background Thread")
        let dispatch = DispatchQueue(label: "background")
        dispatch.async {
            let _ = sut.appViewHierarchyFromMainThread()
            ex.fulfill()
        }

        wait(for: [ex], timeout: 5)
        XCTAssertTrue(fixture.uiApplication.calledOnMainThread, "appViewHierarchy is not using the main thread to get UI windows")
    }

    private class TestSentryUIApplication: SentryUIApplication {

        init() {
            super.init(notificationCenterWrapper: TestNSNotificationCenterWrapper(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        }

        private var _windows: [UIWindow]?
        private var _calledOnMainThread = true

        var calledOnMainThread: Bool {
            return _calledOnMainThread
        }

        override var windows: [UIWindow]? {
            get {
                _calledOnMainThread = Thread.isMainThread
                return _windows
            }
            set {
                _calledOnMainThread = Thread.isMainThread
                _windows = newValue
            }
        }
    }
}
#endif
