#if os(iOS) && !targetEnvironment(macCatalyst)
@testable import Sentry
import UIKit
import XCTest

final class SentryMaskRendererV2Tests: XCTestCase {

    func testMaskScreenshot_whenRegionIsTransformed_shouldMaskOnlyTransformedPixels() throws {
        // -- Arrange --
        //
        // Red 30 x 20 image with a rotated blue mask (* = asserted pixel):
        //
        //             x=0       x=12  x=15  x=17 x=20  x=25     x=30
        //  y=0         +-------------------------------------------+
        //              |                                           |
        //  y=5         |                +------+                   |
        //              |                | blue |                   |
        //  y=10        |       * red    |  *   |     * red         |
        //              |                |      |                   |
        //  y=15        |                +------+                   |
        //              |                                           |
        //  y=20        +-------------------------------------------+
        //
        // The 10 x 5 region is rotated 90 degrees to x=15...20, y=5...15.
        let image = makeImage(size: CGSize(width: 30, height: 20)) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
        }
        let region = SentryRedactRegion(
            size: CGSize(width: 10, height: 5),
            transform: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 20, ty: 5),
            type: .redact,
            color: .blue,
            name: "rotated mask"
        )
        let sut = SentryMaskRendererV2()

        // -- Act --
        let result = sut.maskScreenshot(screenshot: image, size: image.size, masking: [region])

        // -- Assert --
        assertColor(.red, at: CGPoint(x: 12, y: 10), in: result)
        assertColor(.blue, at: CGPoint(x: 17, y: 10), in: result)
        assertColor(.red, at: CGPoint(x: 25, y: 10), in: result)
    }

    func testMaskScreenshot_whenColorIsNotProvided_shouldFillRegionWithAverageColor() throws {
        // -- Arrange --
        //
        // Source image:
        //
        //  x=0              x=10             x=20
        //   +-----------------+-----------------+
        //   | black           | white           |
        //   +-----------------+-----------------+
        //
        // Expected masked image (* = asserted pixel, both at y=5):
        //
        //  x=0                                  x=20
        //   +-------------------------------------+
        //   | average gray                        |
        //   |        * x=5              * x=15    |
        //   +-------------------------------------+
        let image = makeImage(size: CGSize(width: 20, height: 10)) { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
            UIColor.white.setFill()
            context.fill(CGRect(x: 10, y: 0, width: 10, height: 10))
        }
        let region = SentryRedactRegion(
            size: image.size,
            transform: .identity,
            type: .redact,
            name: "image mask"
        )
        let sut = SentryMaskRendererV2()

        // -- Act --
        let result = sut.maskScreenshot(screenshot: image, size: image.size, masking: [region])

        // -- Assert --
        let left = try XCTUnwrap(color(at: CGPoint(x: 5, y: 5), in: result))
        let right = try XCTUnwrap(color(at: CGPoint(x: 15, y: 5), in: result))
        XCTAssertEqual(left.red, right.red, accuracy: 0.01)
        XCTAssertEqual(left.green, right.green, accuracy: 0.01)
        XCTAssertEqual(left.blue, right.blue, accuracy: 0.01)
        XCTAssertEqual(left.red, 0.5, accuracy: 0.1)
        XCTAssertEqual(left.green, 0.5, accuracy: 0.1)
        XCTAssertEqual(left.blue, 0.5, accuracy: 0.1)
    }

    func testMaskScreenshot_whenMaskIsClipped_shouldPreservePixelsOutsideClip() throws {
        // -- Arrange --
        //
        // Red 30 x 20 image with clip x=10...20, y=5...15:
        //
        //             x=0     x=5  x=10     x=15 x=20  x=25    x=30
        //  y=0         +------------------------------------------+
        //              | red                                      |
        //  y=5         |          +-------------+                 |
        //              |          | blue        |                 |
        //  y=10        |    * red |      *      |    * red        |
        //              |          |             |                 |
        //  y=15        |          +-------------+                 |
        //              | red                                      |
        //  y=20        +------------------------------------------+
        //
        // The blue mask requests the full image, but only pixels inside the clip change.
        let image = makeImage(size: CGSize(width: 30, height: 20)) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
        }
        let regions = [
            SentryRedactRegion(
                size: CGSize(width: 10, height: 10),
                transform: CGAffineTransform(translationX: 10, y: 5),
                type: .clipBegin,
                name: "clip"
            ),
            SentryRedactRegion(
                size: image.size,
                transform: .identity,
                type: .redact,
                color: .blue,
                name: "clipped mask"
            ),
            SentryRedactRegion(
                size: .zero,
                transform: .identity,
                type: .clipEnd,
                name: "clip end"
            )
        ]
        let sut = SentryMaskRendererV2()

        // -- Act --
        let result = sut.maskScreenshot(screenshot: image, size: image.size, masking: regions)

        // -- Assert --
        assertColor(.red, at: CGPoint(x: 5, y: 10), in: result)
        assertColor(.blue, at: CGPoint(x: 15, y: 10), in: result)
        assertColor(.red, at: CGPoint(x: 25, y: 10), in: result)
    }

    private func makeImage(size: CGSize, drawing: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            drawing(context.cgContext)
        }
    }

    private func assertColor(
        _ expected: UIColor,
        at point: CGPoint,
        in image: UIImage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual = color(at: point, in: image) else {
            return XCTFail("Could not read image pixel at \(point)", file: file, line: line)
        }

        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0
        guard expected.getRed(&expectedRed, green: &expectedGreen, blue: &expectedBlue, alpha: &expectedAlpha) else {
            return XCTFail("Could not convert expected color to RGB", file: file, line: line)
        }

        XCTAssertEqual(actual.red, expectedRed, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.green, expectedGreen, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.blue, expectedBlue, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.alpha, expectedAlpha, accuracy: 0.01, file: file, line: line)
    }

    private func color(at point: CGPoint, in image: UIImage) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        guard let cgImage = image.cgImage,
              let pixelData = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(pixelData) else {
            return nil
        }

        let x = Int(point.x * image.scale)
        let y = Int(point.y * image.scale)
        guard x >= 0, x < cgImage.width, y >= 0, y < cgImage.height else {
            return nil
        }

        let offset = y * cgImage.bytesPerRow + x * 4
        return (
            CGFloat(bytes[offset]) / 255,
            CGFloat(bytes[offset + 1]) / 255,
            CGFloat(bytes[offset + 2]) / 255,
            CGFloat(bytes[offset + 3]) / 255
        )
    }
}
#endif
