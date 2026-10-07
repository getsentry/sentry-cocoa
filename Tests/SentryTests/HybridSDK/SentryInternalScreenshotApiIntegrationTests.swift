#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

class SentryInternalScreenshotApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalScreenshotApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalScreenshotApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
        super.tearDown()
    }

    // MARK: - accessor

    func testScreenshot_shouldBeAccessible() {
        // -- Act --
        let screenshot = SentrySDK.internal.screenshot

        // -- Assert --
        XCTAssertNotNil(screenshot)
    }

    // MARK: - capture

    func testCapture_whenNoWindows_shouldReturnEmptyArray() {
        // -- Act --
        let result = SentrySDK.internal.screenshot.capture()

        // -- Assert --
        XCTAssertEqual(result, [])
    }

    func testCapture_whenRetinaImageRendered_shouldPreserveResolutionAndRedaction() throws {
        for enableMaskRendererV2 in [false, true] {
            for scale: CGFloat in [2, 3] {
                // -- Arrange --
                let size = CGSize(width: 30, height: 20)
                let window = UIWindow(windowScene: MockUIWindowScene())
                window.frame = CGRect(origin: .zero, size: size)
                window.layer.isHidden = false
                let label = UILabel(frame: CGRect(x: 10, y: 5, width: 10, height: 10))
                label.text = "Private"
                label.textColor = .green
                window.addSubview(label)
                let application = TestSentryUIApplication()
                application.windows = [window]
                let renderer = TestSentryViewRenderer()
                let format = UIGraphicsImageRendererFormat()
                format.scale = scale
                renderer.mockedReturnValue = UIGraphicsImageRenderer(size: size, format: format).image { context in
                    UIColor.red.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                }
                let container = SentryDependencyContainer.sharedInstance()
                container.applicationOverride = application
                container.screenshotSource = SentryScreenshotSource(photographer: SentryViewPhotographer(
                    renderer: renderer,
                    redactOptions: SentryRedactDefaultOptions(),
                    enableMaskRendererV2: enableMaskRendererV2))

                // -- Act --
                // React Native uses this same bridge for feedback and error screenshots.
                let data = try XCTUnwrap(SentrySDK.internal.screenshot.capture()?.first)
                let image = try XCTUnwrap(UIImage(data: data, scale: scale))

                // -- Assert --
                XCTAssertEqual(try XCTUnwrap(image.cgImage).width, Int(size.width * scale))
                XCTAssertEqual(try XCTUnwrap(image.cgImage).height, Int(size.height * scale))
                XCTAssertEqual(try pixelBytes(in: image, at: CGPoint(x: 15, y: 10)), [0, 255, 0, 255])
                XCTAssertEqual(try pixelBytes(in: image, at: CGPoint(x: 5, y: 10)), [255, 0, 0, 255])
            }
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
}

#endif
