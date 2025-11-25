@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryScreenshotSourceTests: XCTestCase {
    private class Fixture {
        let uiApplication = TestSentryUIApplication()
        let renderer = TestSentryViewRenderer()
        let photographer: TestSentryViewPhotographer

        let mockImage = UIImage()

        init() {
            renderer.mockedReturnValue = mockImage
            photographer = TestSentryViewPhotographer(
                renderer: renderer,
                redactOptions: SentryRedactDefaultOptions()
            )
        }

        var sut: SentryScreenshotSource {
            return SentryScreenshotSource(photographer: photographer)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryDependencyContainer.sharedInstance().applicationOverride = fixture.uiApplication
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testappScreenshotsFromMainThread_IsMainThread() throws {
        // -- Arrange --
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        var isMainThread = false
        let onRenderCalledExpectation = self.expectation(description: "onDrawHierarchy called")

        fixture.uiApplication.windows = [testWindow]
        fixture.renderer.onRender = { _ in
            onRenderCalledExpectation.fulfill()
            isMainThread = Thread.isMainThread
        }
        
        // -- Act --
        let expect = expectation(description: "Screenshot")
        let queue = DispatchQueue(label: "TestQueue")
        let _ = queue.async {
            _ = self.fixture.sut.appScreenshotsFromMainThread()
            expect.fulfill()
        }
        wait(for: [expect], timeout: 1)

        // -- Assert --
        wait(for: [onRenderCalledExpectation], timeout: 1)
        XCTAssertTrue(isMainThread)

        let invocation = try XCTUnwrap(fixture.renderer.renderInvocations.first)
        XCTAssertIdentical(invocation.value, testWindow)
    }
    
    func test_Draw_Each_Window() throws {
        // -- Arrange --
        let firstWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let secondWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))

        fixture.uiApplication.windows = [firstWindow, secondWindow]

        // -- Act --
        _ = self.fixture.sut.appScreenshotsData()

        // -- Assert --
        XCTAssertEqual(fixture.renderer.renderInvocations.count, 2)
        let firstInvocation = try XCTUnwrap(fixture.renderer.renderInvocations.first)
        XCTAssertIdentical(firstInvocation.value, firstWindow)
        let secondInvocation = try XCTUnwrap(fixture.renderer.renderInvocations.last)
        XCTAssertIdentical(secondInvocation.value, secondWindow)
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

    private class TestWindow: UIWindow {
        var onDrawHierarchy: (() -> Void)?
        
        override func drawHierarchy(in rect: CGRect, afterScreenUpdates afterUpdates: Bool) -> Bool {
            onDrawHierarchy?()
            return true
        }
    }
   
}
#endif
