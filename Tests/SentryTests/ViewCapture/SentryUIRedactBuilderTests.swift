import UIKit
import SwiftUI
import XCTest
@_spi(Private) @testable import Sentry

class SentryUIRedactBuilderTests: XCTestCase {

    // MARK: - Helper Methods

    func createMaskedScreenshot(view: UIView, regions: [SentryRedactRegion]) -> UIImage {
        let image = SentryViewRendererV2(enableFastViewRendering: true).render(view: view)
        return SentryMaskRendererV2().maskScreenshot(screenshot: image, size: view.bounds.size, masking: regions)
    }

    /// Creates a fake instance of a view for tests.
    ///
    /// - Parameter frame: The frame to set for the created view
    /// - Returns: The created view or `nil` if the type is absent
    func createFakeView<T: UIView>(type: T.Type, name: String, frame: CGRect) throws -> T? {
        // Obtain class at runtime – return nil if unavailable
        guard let viewClass = NSClassFromString(name) else {
            return nil
        }

        // Allocate instance without calling subclass initializers
        let instance = try XCTUnwrap(class_createInstance(viewClass, 0) as? T)

        // Reinitialize storage using UIView.initWithFrame(_:) similar to other helpers
        typealias InitWithFrame = @convention(c) (AnyObject, Selector, CGRect) -> AnyObject
        let sel = NSSelectorFromString("initWithFrame:")
        let m = try XCTUnwrap(class_getInstanceMethod(UIView.self, sel))
        let f = unsafeBitCast(method_getImplementation(m), to: InitWithFrame.self)
        _ = f(instance, sel, frame)

        return instance
    }

    func hostSwiftUIViewInWindow<V: View>(_ swiftUIView: V, frame: CGRect) -> UIWindow {
        // Setup hosting controller containment properly
        let hostingVC = UIHostingController(rootView: swiftUIView)

        // Create a transient window to drive lifecycle/layout for SwiftUI
        let window = UIWindow(frame: frame)
        window.rootViewController = hostingVC
        window.makeKeyAndVisible()

        // Pump the runloop and force layout to allow SwiftUI to build internals
        hostingVC.view.setNeedsLayout()
        hostingVC.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        return window
    }
}

func XCTAssertAffineTransformEqual(_ lhs: CGAffineTransform, _ rhs: CGAffineTransform, accuracy: CGFloat, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(lhs.a, rhs.a, accuracy: accuracy, "Transformation a-factor should be the same: \(lhs.a) != \(rhs.a) (+- \(accuracy))", file: file, line: line)
    XCTAssertEqual(lhs.b, rhs.b, accuracy: accuracy, "Transformation b-factor should be the same: \(lhs.b) != \(rhs.b) (+- \(accuracy))", file: file, line: line)
    XCTAssertEqual(lhs.c, rhs.c, accuracy: accuracy, "Transformation c-factor should be the same: \(lhs.c) != \(rhs.c) (+- \(accuracy))", file: file, line: line)
    XCTAssertEqual(lhs.d, rhs.d, accuracy: accuracy, "Transformation d-factor should be the same: \(lhs.d) != \(rhs.d) (+- \(accuracy))", file: file, line: line)
    XCTAssertEqual(lhs.tx, rhs.tx, accuracy: accuracy, "Transformation x-translation should be the same: \(lhs.tx) != \(rhs.tx) (+- \(accuracy))", file: file, line: line)
    XCTAssertEqual(lhs.ty, rhs.ty, accuracy: accuracy, "Transformation y-translation should be the same: \(lhs.ty) != \(rhs.ty) (+- \(accuracy))", file: file, line: line)
}
