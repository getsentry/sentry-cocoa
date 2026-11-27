#if os(iOS) && !targetEnvironment(macCatalyst)
@_spi(Private) @testable import Sentry
import UIKit
import XCTest

final class SentryViewPhotographerV2Tests: XCTestCase {

    func testImage_whenUsingRendererV2_shouldApplyTextImageExplicitMaskAndExplicitUnmaskToFinalPixels() throws {
        // -- Arrange --
        //
        // Root view hierarchy:
        //
        //  x=0              x=20             x=40             x=60             x=80
        //   +-----------------+-----------------+-----------------+-----------------+
        //   | masked UILabel  | unmasked UILabel| masked image    | masked UIView   |
        //   | yellow, red text| green, blue text| black / white   | cyan / magenta  |
        //   +-----------------+-----------------+-----------------+-----------------+
        //
        // Expected final pixels (* = asserted pixel, labels at y=2, others at y=10):
        //
        //   +-----------------+-----------------+-----------------+-----------------+
        //   | red mask        | unchanged       | average gray    | average blue    |
        //   | *2 red          | *22 green       | *45       *55   | *65       *75   |
        //   +-----------------+-----------------+-----------------+-----------------+
        //
        // Each average replaces two different source colors with one uniform mask color.
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 20))
        rootView.backgroundColor = .white

        let maskedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        maskedLabel.backgroundColor = .yellow
        maskedLabel.textColor = .red
        maskedLabel.text = "Private"
        rootView.addSubview(maskedLabel)

        let unmaskedLabel = UILabel(frame: CGRect(x: 20, y: 0, width: 20, height: 20))
        unmaskedLabel.backgroundColor = .green
        unmaskedLabel.textColor = .blue
        unmaskedLabel.text = "Visible"
        SentryRedactViewHelper.unmaskView(unmaskedLabel)
        rootView.addSubview(unmaskedLabel)

        let imageView = UIImageView(frame: CGRect(x: 40, y: 0, width: 20, height: 20))
        imageView.image = makeSplitImage(leftColor: .black, rightColor: .white)
        rootView.addSubview(imageView)

        let explicitlyMaskedView = UIView(frame: CGRect(x: 60, y: 0, width: 20, height: 20))
        let cyanSubview = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 20))
        cyanSubview.backgroundColor = .cyan
        explicitlyMaskedView.addSubview(cyanSubview)
        let magentaSubview = UIView(frame: CGRect(x: 10, y: 0, width: 10, height: 20))
        magentaSubview.backgroundColor = .magenta
        explicitlyMaskedView.addSubview(magentaSubview)
        SentryRedactViewHelper.maskView(explicitlyMaskedView)
        rootView.addSubview(explicitlyMaskedView)

        let sut = SentryViewPhotographer(
            renderer: SentryViewRendererV2(enableFastViewRendering: true),
            redactOptions: TestRedactOptions(),
            enableMaskRendererV2: true
        )

        // -- Act --
        let result = sut.image(view: rootView)

        // -- Assert --
        assertImagePixelColor(.red, at: CGPoint(x: 2, y: 2), in: result)
        assertImagePixelColor(.green, at: CGPoint(x: 22, y: 2), in: result)

        let imageMaskLeft = try XCTUnwrap(imagePixel(at: CGPoint(x: 45, y: 10), in: result))
        let imageMaskRight = try XCTUnwrap(imagePixel(at: CGPoint(x: 55, y: 10), in: result))
        assertImagePixelsEqual(imageMaskLeft, imageMaskRight)
        XCTAssertEqual(imageMaskLeft.red, 0.5, accuracy: 0.1)
        XCTAssertEqual(imageMaskLeft.green, 0.5, accuracy: 0.1)
        XCTAssertEqual(imageMaskLeft.blue, 0.5, accuracy: 0.1)

        let explicitMaskLeft = try XCTUnwrap(imagePixel(at: CGPoint(x: 65, y: 10), in: result))
        let explicitMaskRight = try XCTUnwrap(imagePixel(at: CGPoint(x: 75, y: 10), in: result))
        assertImagePixelsEqual(explicitMaskLeft, explicitMaskRight)
        XCTAssertEqual(explicitMaskLeft.red, 0.5, accuracy: 0.1)
        XCTAssertEqual(explicitMaskLeft.green, 0.5, accuracy: 0.1)
        XCTAssertEqual(explicitMaskLeft.blue, 1, accuracy: 0.1)
    }

    func testImage_whenOpaqueViewCoversText_shouldPreserveOpaquePixels() {
        // -- Arrange --
        //
        // Sibling hierarchy (later siblings are on top):
        //
        //  Sensitive UILabel: x=0 +-------------------------------------+ x=40
        //  Opaque green view:                     x=20 +----------------+ x=40
        //
        // Expected final pixels (* = asserted pixel, both at y=10):
        //
        //                     x=0              x=20             x=40
        //                      +-----------------+-----------------+
        //                      | black mask      | opaque green    |
        //                      |  * x=5          |          * x=30 |
        //                      +-----------------+-----------------+
        //
        // The opaque sibling clips the label's mask on the covered right half.
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        rootView.backgroundColor = .white

        let label = UILabel(frame: rootView.bounds)
        label.backgroundColor = .yellow
        label.textColor = .black
        label.text = "Private"
        rootView.addSubview(label)

        let opaqueView = UIView(frame: CGRect(x: 20, y: 0, width: 20, height: 20))
        opaqueView.backgroundColor = .green
        opaqueView.isOpaque = true
        opaqueView.layer.isOpaque = true
        opaqueView.layer.backgroundColor = UIColor.green.cgColor
        rootView.addSubview(opaqueView)

        let sut = SentryViewPhotographer(
            renderer: SentryViewRendererV2(enableFastViewRendering: true),
            redactOptions: TestRedactOptions(),
            enableMaskRendererV2: true
        )

        // -- Act --
        let result = sut.image(view: rootView)

        // -- Assert --
        assertImagePixelColor(.black, at: CGPoint(x: 5, y: 10), in: result)
        assertImagePixelColor(.green, at: CGPoint(x: 30, y: 10), in: result)
    }

    func testImage_whenTransparentViewCoversText_shouldStillMaskCoveredText() {
        // -- Arrange --
        //
        // Sibling hierarchy (later siblings are on top):
        //
        //  Sensitive UILabel: x=0 +-------------------------------------+ x=40
        //  50% green view:                        x=20 +----------------+ x=40
        //
        // Expected final pixels (* = asserted pixel, both at y=10):
        //
        //                     x=0                                  x=40
        //                      +-------------------------------------+
        //                      | black mask over both sibling regions|
        //                      |  * x=5                    * x=30    |
        //                      +-------------------------------------+
        //
        // The transparent sibling must not clip the label's mask.
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        rootView.backgroundColor = .white

        let label = UILabel(frame: rootView.bounds)
        label.backgroundColor = .yellow
        label.textColor = .black
        label.text = "Private"
        rootView.addSubview(label)

        let transparentView = UIView(frame: CGRect(x: 20, y: 0, width: 20, height: 20))
        transparentView.backgroundColor = .green
        transparentView.alpha = 0.5
        rootView.addSubview(transparentView)

        let sut = SentryViewPhotographer(
            renderer: SentryViewRendererV2(enableFastViewRendering: true),
            redactOptions: TestRedactOptions(),
            enableMaskRendererV2: true
        )

        // -- Act --
        let result = sut.image(view: rootView)

        // -- Assert --
        assertImagePixelColor(.black, at: CGPoint(x: 5, y: 10), in: result)
        assertImagePixelColor(.black, at: CGPoint(x: 30, y: 10), in: result)
    }

    private func makeSplitImage(leftColor: UIColor, rightColor: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20), format: format).image { context in
            leftColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 20))
            rightColor.setFill()
            context.fill(CGRect(x: 10, y: 0, width: 10, height: 20))
        }
    }

}
#endif
