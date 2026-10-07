#if os(iOS) && !targetEnvironment(macCatalyst)
@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import UIKit
import XCTest

extension SentryViewPhotographerTests {
    func testTimedImage_whenCapturingAfterRetinaStill_shouldKeepReplayAtOneX() throws {
        for enableMaskRendererV2 in [false, true] {
            // -- Arrange --
            let size = CGSize(width: 30, height: 20)
            let view = UIView(frame: CGRect(origin: .zero, size: size))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            let renderer = TestSentryViewRenderer()
            renderer.mockedReturnValue = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.red.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            let sut = SentryViewPhotographer(
                renderer: renderer,
                redactOptions: SentryRedactDefaultOptions(),
                enableMaskRendererV2: enableMaskRendererV2
            )
            let replayCapture = expectation(description: "Replay capture after still image")
            var replayImage: UIImage?

            // -- Act --
            let stillImage = sut.image(view: view)
            sut.timedImage(view: view) { image, _ in
                replayImage = image
                replayCapture.fulfill()
            }
            wait(for: [replayCapture], timeout: 1)

            // -- Assert --
            XCTAssertEqual(stillImage.scale, 3)
            XCTAssertEqual(try XCTUnwrap(stillImage.cgImage).width, Int(size.width * 3))
            XCTAssertEqual(try XCTUnwrap(stillImage.cgImage).height, Int(size.height * 3))
            let image = try XCTUnwrap(replayImage)
            XCTAssertEqual(image.scale, 1)
            XCTAssertEqual(try XCTUnwrap(image.cgImage).width, Int(size.width))
            XCTAssertEqual(try XCTUnwrap(image.cgImage).height, Int(size.height))
        }
    }
}
#endif
