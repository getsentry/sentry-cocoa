@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)
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
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
    func testappScreenshotsFromMainThread_IsMainThread() throws {
        // -- Arrange --
        let testWindow = TestWindow(testFrame: CGRect(x: 0, y: 0, width: 10, height: 10))
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
        let firstWindow = TestWindow(testFrame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let secondWindow = TestWindow(testFrame: CGRect(x: 0, y: 0, width: 10, height: 10))

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
        let testWindow = TestWindow(testFrame: CGRect(x: 0, y: 0, width: 10, height: 10))
        fixture.uiApplication.windows = [testWindow]
        
        let data = self.fixture.sut.appScreenshotsData()
        let image = UIImage(data: try XCTUnwrap(data.first))
        
        XCTAssertEqual(image?.size.width, 10)
        XCTAssertEqual(image?.size.height, 10)
    }

    func testAppScreenshots_whenRetinaImageRendered_shouldPreserveResolutionAndRedaction() throws {
        for enableMaskRendererV2 in [false, true] {
            for scale: CGFloat in [2, 3] {
                // -- Arrange --
                let size = CGSize(width: 30, height: 20)
                let window = TestWindow(testFrame: CGRect(origin: .zero, size: size))
                // The redaction builder skips hidden layers; no real window presentation is needed.
                window.layer.isHidden = false
                let label = UILabel(frame: CGRect(x: 10, y: 5, width: 10, height: 10))
                label.text = "Private"
                label.textColor = .green
                window.addSubview(label)
                fixture.uiApplication.windows = [window]
                let format = UIGraphicsImageRendererFormat()
                format.scale = scale
                fixture.renderer.mockedReturnValue = UIGraphicsImageRenderer(size: size, format: format).image { context in
                    UIColor.red.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                }
                let photographer = SentryViewPhotographer(
                    renderer: fixture.renderer,
                    redactOptions: SentryRedactDefaultOptions(),
                    enableMaskRendererV2: enableMaskRendererV2
                )
                let sut = SentryScreenshotSource(photographer: photographer)

                // -- Act --
                let image = try XCTUnwrap(sut.appScreenshotsFromMainThread().first)
                let data = try XCTUnwrap(sut.appScreenshotDatasFromMainThread().first)
                let png = try XCTUnwrap(UIImage(data: data)?.cgImage)

                // -- Assert --
                XCTAssertEqual(image.size, size)
                XCTAssertEqual(image.scale, scale)
                XCTAssertEqual(try XCTUnwrap(image.cgImage).width, Int(size.width * scale))
                XCTAssertEqual(try XCTUnwrap(image.cgImage).height, Int(size.height * scale))
                XCTAssertEqual(png.width, Int(size.width * scale))
                XCTAssertEqual(png.height, Int(size.height * scale))
                XCTAssertEqual(try pixelBytes(in: image, at: CGPoint(x: 15, y: 10)), [0, 255, 0, 255])
                XCTAssertEqual(try pixelBytes(in: image, at: CGPoint(x: 5, y: 10)), [255, 0, 0, 255])
            }
        }
    }

    func testSaveScreenShots_whenRetinaImageRendered_shouldPreserveResolutionAndRedaction() throws {
        for enableMaskRendererV2 in [false, true] {
            // -- Arrange --
            let size = CGSize(width: 30, height: 20)
            let window = TestWindow(testFrame: CGRect(origin: .zero, size: size))
            window.layer.isHidden = false
            let label = UILabel(frame: CGRect(x: 10, y: 5, width: 10, height: 10))
            label.text = "Private"
            label.textColor = .green
            window.addSubview(label)
            fixture.uiApplication.windows = [window]
            let appDelegate = TestApplicationDelegate()
            appDelegate.window = window
            fixture.uiApplication.appDelegate = appDelegate
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            fixture.renderer.mockedReturnValue = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.red.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            let photographer = SentryViewPhotographer(
                renderer: fixture.renderer,
                redactOptions: SentryRedactDefaultOptions(),
                enableMaskRendererV2: enableMaskRendererV2
            )
            let sut = SentryScreenshotSource(photographer: photographer)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer {
                do {
                    try FileManager.default.removeItem(at: directory)
                } catch {
                    XCTFail("Failed to remove screenshot test directory: \(error)")
                }
            }

            // -- Act --
            withExtendedLifetime(appDelegate) {
                sut.saveScreenShots(directory.path)
            }
            let data = try Data(contentsOf: directory.appendingPathComponent("screenshot.png"))
            let crashImage = try XCTUnwrap(UIImage(data: data, scale: 3))

            // -- Assert --
            XCTAssertEqual(try XCTUnwrap(crashImage.cgImage).width, Int(size.width * 3))
            XCTAssertEqual(try XCTUnwrap(crashImage.cgImage).height, Int(size.height * 3))
            XCTAssertEqual(try pixelBytes(in: crashImage, at: CGPoint(x: 15, y: 10)), [0, 255, 0, 255])
            XCTAssertEqual(try pixelBytes(in: crashImage, at: CGPoint(x: 5, y: 10)), [255, 0, 0, 255])
        }
    }

    private func pixelBytes(in image: UIImage, at point: CGPoint) throws -> [UInt8] {
        let pixelRect = CGRect(x: point.x * image.scale, y: point.y * image.scale, width: 1, height: 1)
        let cropped = try XCTUnwrap(image.cgImage?.cropping(to: pixelRect))
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: bytes, count: 4))
    }

    func test_ZeroSizeScreenShot_GetsDiscarded() {
        let testWindow = TestWindow(testFrame: CGRect(x: 0, y: 0, width: 0, height: 0))
        fixture.uiApplication.windows = [testWindow]

        let data = self.fixture.sut.appScreenshotsData()

        XCTAssertEqual(0, data.count, "No screenshot should be taken, cause the image has zero size.")
    }

    func test_ZeroWidthScreenShot_GetsDiscarded() {
        let testWindow = TestWindow(testFrame: CGRect(x: 0, y: 0, width: 0, height: 1_000))
        fixture.uiApplication.windows = [testWindow]

        let data = self.fixture.sut.appScreenshotsData()

        XCTAssertEqual(0, data.count, "No screenshot should be taken, cause the image has zero width.")
    }

    func test_ZeroHeightScreenShot_GetsDiscarded() {
        let testWindow = TestWindow(testFrame: CGRect(x: 0, y: 0, width: 1_000, height: 0))
        fixture.uiApplication.windows = [testWindow]

        let data = self.fixture.sut.appScreenshotsData()

        XCTAssertEqual(0, data.count, "No screenshot should be taken, cause the image has zero height.")
    }

    private static let mockWindowScene: UIWindowScene = {
        MockUIWindowScene()
    }()

    private class TestWindow: UIWindow {
        var onDrawHierarchy: (() -> Void)?

        convenience init(testFrame frame: CGRect) {
            self.init(windowScene: SentryScreenshotSourceTests.mockWindowScene)
            self.frame = frame
        }

        override func drawHierarchy(in rect: CGRect, afterScreenUpdates afterUpdates: Bool) -> Bool {
            onDrawHierarchy?()
            return true
        }
    }
   
}
#endif
