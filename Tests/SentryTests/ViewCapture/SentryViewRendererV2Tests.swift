#if os(iOS) && !targetEnvironment(macCatalyst)
@testable import Sentry
import UIKit
import XCTest

final class SentryViewRendererV2Tests: XCTestCase {

    func testRender_whenUsingDrawHierarchy_shouldUseDrawHierarchyAtScreenScale() throws {
        // -- Arrange --
        //
        // DrawHierarchyView output (* = asserted pixel):
        //
        //  x=0              x=20             x=40
        //   +-----------------+-----------------+
        //   | red             | blue            |
        //   |  * x=5          |          * x=30 |
        //   +-----------------+-----------------+
        //
        // The overriding view draws both halves through drawHierarchy.
        let view = DrawHierarchyView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))

        let window = hostInWindow(view)
        defer { window.isHidden = true }
        let sut = SentryViewRendererV2(enableFastViewRendering: false)

        // -- Act --
        let image = sut.render(view: view)

        // -- Assert --
        XCTAssertEqual(view.drawnRect, view.bounds)
        XCTAssertEqual(view.drawnAfterScreenUpdates, false)
        XCTAssertEqual(image.size, view.bounds.size)
        XCTAssertEqual(image.scale, window.screen.scale)
        XCTAssertEqual(try XCTUnwrap(image.cgImage).width, Int(view.bounds.width * window.screen.scale))
        assertColor(.red, at: CGPoint(x: 5, y: 10), in: image)
        assertColor(.blue, at: CGPoint(x: 30, y: 10), in: image)
    }

    func testRender_whenUsingFastRendering_shouldRenderSublayers() {
        // -- Arrange --
        //
        // Layer hierarchy:
        //
        //  Red parent:     x=0 +-----------------------------------+ x=40
        //  Blue subview:                    x=20 +-----------------+ x=40
        //
        // Expected composite (* = asserted pixel):
        //
        //                    x=0              x=20             x=40
        //                     +-----------------+-----------------+
        //                     | red             | blue subview    |
        //                     |  * x=5          |          * x=30 |
        //                     +-----------------+-----------------+
        //
        // The blue half must come from the subview's layer, not the parent layer.
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        view.backgroundColor = .red

        let subview = UIView(frame: CGRect(x: 20, y: 0, width: 20, height: 20))
        subview.backgroundColor = .blue
        view.addSubview(subview)

        let window = hostInWindow(view)
        defer { window.isHidden = true }
        let sut = SentryViewRendererV2(enableFastViewRendering: true)

        // -- Act --
        let image = sut.render(view: view)

        // -- Assert --
        assertColor(.red, at: CGPoint(x: 5, y: 10), in: image)
        assertColor(.blue, at: CGPoint(x: 30, y: 10), in: image)
    }

    private final class DrawHierarchyView: UIView {
        var drawnRect: CGRect?
        var drawnAfterScreenUpdates: Bool?

        override func drawHierarchy(in rect: CGRect, afterScreenUpdates afterUpdates: Bool) -> Bool {
            drawnRect = rect
            drawnAfterScreenUpdates = afterUpdates

            UIColor.red.setFill()
            UIRectFill(bounds)
            UIColor.blue.setFill()
            UIRectFill(CGRect(x: bounds.midX, y: 0, width: bounds.width / 2, height: bounds.height))
            return true
        }
    }

    private func hostInWindow(_ view: UIView) -> UIWindow {
        let viewController = UIViewController()
        viewController.view = view

        let window = UIWindow(frame: view.bounds)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        return window
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
