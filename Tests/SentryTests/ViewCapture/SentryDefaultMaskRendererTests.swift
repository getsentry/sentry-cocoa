#if os(iOS) && !targetEnvironment(macCatalyst)
@testable import Sentry
import UIKit
import XCTest

final class SentryDefaultMaskRendererTests: XCTestCase {
    func testMaskScreenshot_whenScaled_shouldPreserveTransformsAndClipping() throws {
        for renderer in [SentryDefaultMaskRenderer(), SentryMaskRendererV2()] {
            for scale: CGFloat in [2, 3] {
                // -- Arrange --
                let size = CGSize(width: 60, height: 60)
                let format = UIGraphicsImageRendererFormat()
                format.scale = scale
                let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                    UIColor.red.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                }
                // Rotate the mask to x=15...20, y=5...15. The opaque region clips out
                // its upper half. After clipEnd, the bottom green mask must still draw.
                let regions = [
                    SentryRedactRegion(size: CGSize(width: 40, height: 40), transform: CGAffineTransform(translationX: 10, y: 0), type: .clipBegin, name: "clip"),
                    SentryRedactRegion(size: CGSize(width: 5, height: 5), transform: CGAffineTransform(translationX: 15, y: 5), type: .clipOut, name: "opaque view"),
                    SentryRedactRegion(size: CGSize(width: 10, height: 5), transform: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 20, ty: 5), type: .redact, color: .blue, name: "rotated mask"),
                    SentryRedactRegion(size: .zero, transform: .identity, type: .clipEnd, name: "clip end"),
                    SentryRedactRegion(size: CGSize(width: 10, height: 10), transform: CGAffineTransform(translationX: 0, y: 50), type: .redactSwiftUI, color: .green, name: "outside clip")
                ]

                // -- Act --
                let result = renderer.maskScreenshot(screenshot: image, size: size, masking: regions, scale: scale)
                let normalized = try normalize(result)

                // -- Assert --
                XCTAssertEqual(result.scale, scale)
                XCTAssertEqual(try XCTUnwrap(result.cgImage).width, Int(size.width * scale))
                assertImagePixelColor(.blue, at: CGPoint(x: 17, y: 12), in: normalized)
                assertImagePixelColor(.red, at: CGPoint(x: 17, y: 7), in: normalized)
                assertImagePixelColor(.red, at: CGPoint(x: 5, y: 12), in: normalized)
                assertImagePixelColor(.green, at: CGPoint(x: 5, y: 55), in: normalized)
            }
        }
    }

    func testMaskScreenshot_whenScaled_shouldAverageTheCorrectImageRegion() throws {
        for renderer in [SentryDefaultMaskRenderer(), SentryMaskRendererV2()] {
            for scale: CGFloat in [2, 3] {
                // -- Arrange --
                let size = CGSize(width: 60, height: 60)
                let format = UIGraphicsImageRendererFormat()
                format.scale = scale
                let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                    UIColor.red.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    UIColor.black.setFill()
                    context.fill(CGRect(x: 20, y: 20, width: 10, height: 20))
                    UIColor.white.setFill()
                    context.fill(CGRect(x: 30, y: 20, width: 10, height: 20))
                }
                let region = SentryRedactRegion(size: CGSize(width: 20, height: 20), transform: CGAffineTransform(translationX: 20, y: 20), type: .redact, name: "image")

                // -- Act --
                let result = renderer.maskScreenshot(screenshot: image, size: size, masking: [region], scale: scale)
                let normalized = try normalize(result)

                // -- Assert --
                assertImagePixelColor(UIColor(white: 0.5, alpha: 1), at: CGPoint(x: 25, y: 25), in: normalized, accuracy: 0.05)
                assertImagePixelColor(UIColor(white: 0.5, alpha: 1), at: CGPoint(x: 35, y: 25), in: normalized, accuracy: 0.05)
                assertImagePixelColor(.red, at: CGPoint(x: 5, y: 5), in: normalized)
            }
        }
    }

    // UIGraphicsImageRenderer can return extended-range pixels; the pixel assertions
    // expect 8-bit RGBA. Normalize without resizing or changing the image's scale.
    private func normalize(_ image: UIImage) throws -> UIImage {
        let cgImage = try XCTUnwrap(image.cgImage)
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return UIImage(cgImage: try XCTUnwrap(context.makeImage()), scale: image.scale, orientation: .up)
    }
}
#endif
