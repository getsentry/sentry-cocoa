// swiftlint:disable test_case_accessibility

#if os(iOS) && !targetEnvironment(macCatalyst)
@_spi(Private) @testable import Sentry
import SwiftUI
import UIKit
import XCTest

/// To print the internal view hierarchy of a view in the test cases, follow these steps:
///
/// 1. Set a breakpoint in the test case after creating the view instance.
/// 2. Run the test case.
/// 3. In the debugger, print the view hierarchy by evaluating the following expression in `lldb`:
///
/// ```
/// (lldb) po view.value(forKey: "recursiveDescription")!
/// ```
///
/// Example output:
///
/// ```
/// <UIView: 0x12be081f0; frame = (0 0; 100 100); layer = <CALayer: 0x600001161840>>
///   | <UILabel: 0x14bd5e8b0; frame = (20 10; 40 5); hidden = YES; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600003244eb0>>
///   | <UILabel: 0x12be0b2b0; frame = (20 20; 50 8); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x60000323ceb0>>
/// ```
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
        //  Setup hosting controller containment properly
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

    /// Creates a snapshot test identifier for a named snapshot in the test
    ///
    /// - Parameter name: Name of the snapshot in the current test, must be unique per test
    /// - Returns Snapshot identifier bound to the current device OS
    func createTestDeviceOSBoundSnapshotName(name: String) -> String {
        let device = UIDevice.current
        return "\(device.name).\(device.systemName)-\(device.systemVersion).\(name)"
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

func XCTAssertCGSizeEqual(_ lhs: CGSize, _ rhs: CGSize, accuracy: CGFloat, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(lhs.width, rhs.width, accuracy: accuracy, "Width should be the same: \(lhs.width) != \(rhs.width) (+- \(accuracy))", file: file, line: line)
    XCTAssertEqual(lhs.height, rhs.height, accuracy: accuracy, "Height should be the same: \(lhs.height) != \(rhs.height) (+- \(accuracy))", file: file, line: line)
}
#endif // os(iOS) && !targetEnvironment(macCatalyst)
// swiftlint:enable test_case_accessibility
