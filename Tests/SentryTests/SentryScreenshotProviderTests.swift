@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryScreenshotProviderTests: XCTestCase {
    private class Fixture {
        
        let uiApplication = TestSentryUIApplication(notificationCenterWrapper: TestNSNotificationCenterWrapper(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        
        var sut: SentryScreenshotProvider {
            return SentryScreenshotProvider(
                SentryRedactDefaultOptions(),
                enableViewRendererV2: false,
                enableFastViewRendering: false
            )
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryDependencyContainer.sharedInstance().application = fixture.uiApplication
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func test_IsMainThread() {
        // -- Arrange --
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        var isMainThread = false
        
        testWindow.onDrawHierarchy = {
            isMainThread = Thread.isMainThread
        }
        
        fixture.uiApplication.windows = [testWindow]
        
        // -- Act --
        let expect = expectation(description: "Screenshot")
        let queue = DispatchQueue(label: "TestQueue")
        let _ = queue.async {
            self.fixture.sut.appScreenshotsFromMainThread()
            expect.fulfill()
        }
        wait(for: [expect], timeout: 1)

        // -- Assert --
        XCTAssertTrue(isMainThread)
    }
    
    func test_Draw_Each_Window() {
        let firstWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let secondWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        var drawFirstWindow = false
        var drawSecondWindow = false
        
        firstWindow.onDrawHierarchy = {
            drawFirstWindow = true
        }
        secondWindow.onDrawHierarchy = {
            drawSecondWindow = true
        }
        
        fixture.uiApplication.windows = [firstWindow, secondWindow]
        
        self.fixture.sut.appScreenshotsData()
        
        XCTAssertTrue(drawFirstWindow)
        XCTAssertTrue(drawSecondWindow)
    }
    
    func test_image_size() throws {
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        fixture.uiApplication.windows = [testWindow]
        
        let data = self.fixture.sut.appScreenshotsData()
        let image = UIImage(data: try XCTUnwrap(data.first))
        
        XCTAssertEqual(image?.size.width, 10)
        XCTAssertEqual(image?.size.height, 10)
    }

    func test_ZeroSizeScreenShot_GetsDiscarded() {
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        fixture.uiApplication.windows = [testWindow]

        let data = self.fixture.sut.appScreenshotsData()

        XCTAssertEqual(0, data.count, "No screenshot should be taken, cause the image has zero size.")
    }

    func test_ZeroWidthScreenShot_GetsDiscarded() {
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 1_000))
        fixture.uiApplication.windows = [testWindow]

        let data = self.fixture.sut.appScreenshotsData()

        XCTAssertEqual(0, data.count, "No screenshot should be taken, cause the image has zero width.")
    }

    func test_ZeroHeightScreenShot_GetsDiscarded() {
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 1_000, height: 0))
        fixture.uiApplication.windows = [testWindow]

        let data = self.fixture.sut.appScreenshotsData()

        XCTAssertEqual(0, data.count, "No screenshot should be taken, cause the image has zero height.")
    }
    
    private class TestSentryUIApplication: SentryUIApplication {
        private var _windows: [UIWindow]?
        
        override var windows: [UIWindow]? {
            get {
                return _windows
            }
            set {
                _windows = newValue
            }
        }
    }

    private class TestWindow: UIWindow {
        var onDrawHierarchy: (() -> Void)?
        
        override func drawHierarchy(in rect: CGRect, afterScreenUpdates afterUpdates: Bool) -> Bool {
            onDrawHierarchy?()
            return true
        }
    }
   
}
#endif
