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
        assertImagePixelColor(.red, at: CGPoint(x: 5, y: 10), in: image)
        assertImagePixelColor(.blue, at: CGPoint(x: 30, y: 10), in: image)
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
        assertImagePixelColor(.red, at: CGPoint(x: 5, y: 10), in: image)
        assertImagePixelColor(.blue, at: CGPoint(x: 30, y: 10), in: image)
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

}
#endif
