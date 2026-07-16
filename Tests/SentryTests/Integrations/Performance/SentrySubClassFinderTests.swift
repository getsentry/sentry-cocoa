@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import MachO
import ObjectiveC
import XCTest

#if canImport(SwiftUI)
import SwiftUI
#endif

#if os(iOS) || os(tvOS)
class SentrySubClassFinderTests: XCTestCase {
    
    private class Fixture {
        lazy var runtimeWrapper: SentryTestObjCRuntimeWrapper = {
            let result = SentryTestObjCRuntimeWrapper()
            result.classes = { _ in
                return self.testClasses
            }
            return result
        }()
        let imageName: String
        let testClasses: [AnyClass] = [FirstViewController.self,
                                       SecondViewController.self,
                                       ViewControllerNumberThree.self,
                                       VCAnyNaming.self,
                                       FakeViewController.self]
        init() {
            if let name = class_getImageName(FirstViewController.self) {
                imageName = String(cString: name, encoding: .utf8) ?? ""
            } else {
                imageName = ""
            }
        }

        func getSut(swizzleClassNameExcludes: Set<String> = []) -> SentrySubClassFinder {
            return SentrySubClassFinder(dispatchQueue: TestSentryDispatchQueueWrapper(), objcRuntimeWrapper: runtimeWrapper, swizzleClassNameExcludes: swizzleClassNameExcludes)
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    func testActOnSubclassesOfViewController() {
        assertActOnSubclassesOfViewController(expected: [FirstViewController.self, SecondViewController.self, ViewControllerNumberThree.self, VCAnyNaming.self])
    }

    func testActOnSubclassesOfViewController_WithSwizzleClassNameExcludes() {
        assertActOnSubclassesOfViewController(expected: [SecondViewController.self, ViewControllerNumberThree.self], swizzleClassNameExcludes: ["FirstViewController", "VCAnyNaming"])
    }

    func testActOnSubclassesOfViewController_NoViewController() {
        fixture.runtimeWrapper.classes = { _ in [] }
        assertActOnSubclassesOfViewController(expected: [])
    }

    func testActOnSubclassesOfViewController_IgnoreFakeViewController() {
        fixture.runtimeWrapper.classes = { _ in [FakeViewController.self] }
        assertActOnSubclassesOfViewController(expected: [])
    }

    func testActOnSubclassesOfViewController_WrongImage_NoViewController() {
        fixture.runtimeWrapper.classes = nil
        assertActOnSubclassesOfViewController(expected: [], imageName: "OtherImage")
    }

    func testGettingSubclasses_DoesNotCallInitializer() throws {
        let trackedClassName = try XCTUnwrap(
            SentryInitializeForGettingSubclassesCalled.registerDynamicClass())
        let trackedClass: AnyClass = try XCTUnwrap(NSClassFromString(trackedClassName))
        fixture.runtimeWrapper.classes = { _ in
            return self.fixture.testClasses + [trackedClass]
        }

        assertActOnSubclassesOfViewController(
            expected: [
                FirstViewController.self,
                SecondViewController.self,
                ViewControllerNumberThree.self,
                VCAnyNaming.self
            ])

        XCTAssertFalse(SentryInitializeForGettingSubclassesCalled.wasCalled())
    }

    /// Differential test proving the one thing the fix changed — how classes are enumerated — is
    /// equivalent to the old way, across every image loaded in the test process (thousands of real
    /// classes from every linked framework), on whatever platform and architecture CI runs.
    ///
    /// The fix replaced `objc_copyClassNamesForImage` (which returns names) with reading the
    /// `__objc_classlist` section (which returns class pointers). The subsequent subclass check
    /// (`class_getSuperclass`) is unchanged. So the only new behavior to guard is that the class set
    /// from `__objc_classlist` matches the class set from `objc_copyClassNamesForImage`.
    ///
    /// This test deliberately does NOT call `NSClassFromString`: that realizes classes, which is the
    /// exact operation that crashes for availability-gated classes on older OS versions (GH-8152).
    /// Comparing the two enumerations by name never realizes anything, so the test is safe on every
    /// OS — including ones where the old path would have crashed.
    func testClassListEnumerationMatchesCopyClassNamesForImage() throws {
        let sut = SentryDefaultObjCRuntimeWrapper()

        var comparedImages = 0
        for index in 0..<_dyld_image_count() {
            let imageName = try XCTUnwrap(_dyld_get_image_name(index).map { String(cString: $0) })

            // New enumeration: class pointers from __objc_classlist, named via class_getName.
            let fromClassList = Set(sut.classes(forImage: imageName).map { NSStringFromClass($0) })

            // Old enumeration: names from objc_copyClassNamesForImage.
            var fromCopyNames: Set<String> = []
            imageName.withCString { cImageName in
                var count: UInt32 = 0
                guard let names = objc_copyClassNamesForImage(cImageName, &count) else { return }
                defer { free(UnsafeMutableRawPointer(mutating: names)) }
                for i in 0..<Int(count) {
                    fromCopyNames.insert(String(cString: names[i]))
                }
            }

            XCTAssertEqual(fromClassList, fromCopyNames, "Enumeration mismatch for image \(imageName)")
            if !fromCopyNames.isEmpty { comparedImages += 1 }
        }

        // Ensure the comparison actually ran against images that contain classes (e.g. UIKitCore and
        // this test bundle), so the test can't silently pass on empty input.
        XCTAssertGreaterThan(comparedImages, 0, "Expected at least one image with classes")
    }
    
    private func assertActOnSubclassesOfViewController(expected: [AnyClass], swizzleClassNameExcludes: Set<String> = []) {
        assertActOnSubclassesOfViewController(expected: expected, imageName: fixture.imageName, swizzleClassNameExcludes: swizzleClassNameExcludes)
    }
    
    private func assertActOnSubclassesOfViewController(expected: [AnyClass], imageName: String, swizzleClassNameExcludes: Set<String> = []) {
        let expect = expectation(description: "")
        
        if expected.isEmpty {
            expect.isInverted = true
        } else {
            expect.expectedFulfillmentCount = expected.count
        }
        
        var actual: [AnyClass] = []
        let sut = fixture.getSut(swizzleClassNameExcludes: swizzleClassNameExcludes)
        sut.actOnSubclassesOfViewController(inImage: imageName) { subClass in
            XCTAssertTrue(Thread.isMainThread, "Block must be executed on the main thread.")
            actual.append(subClass)
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 1)
        
        let count = actual.filter { element in
            return expected.contains { ex in
                return element == ex
            }
        }.count
        
        XCTAssertEqual(expected.count, count)
    }
}

class FirstViewController: UIViewController {}
class SecondViewController: UIViewController {}
class ViewControllerNumberThree: UIViewController {}
class VCAnyNaming: UIViewController {}
class FakeViewController {}
#endif

// MARK: - Availability-gated gesture crash reproduction
//
// Mirrors a real crash: an app defines a gesture conforming to
// UIGestureRecognizerRepresentable (iOS 18+) behind @available.
// The nested Coordinator (NSObject subclass) is registered in the ObjC runtime.
// Calling NSClassFromString on it realizes the class, and Swift metadata
// resolution triggers protocol conformance lookup for
// UIGestureRecognizerRepresentable. On iOS versions where the protocol doesn't
// exist, this crashes (GH-8152, swiftlang/swift#72657).
//
// The finder now avoids this by reading the image's class list and walking each
// class's superclass chain with class_getSuperclass, which doesn't realize any
// class. The Coordinator walks to NSObject (it's not a UIViewController), so it
// is never realized and never crashes.

#if os(iOS)

@available(iOS 26.0, *)
private struct TestHorizontalPanGesture: UIGestureRecognizerRepresentable {
    var onChanged: ((CGSize) -> Void)?
    var onEnded: ((CGSize) -> Void)?

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        gesture.maximumNumberOfTouches = 1
        gesture.cancelsTouchesInView = false
        gesture.delegate = context.coordinator
        return gesture
    }

    func updateUIGestureRecognizer(
        _ recognizer: UIPanGestureRecognizer,
        context: Context
    ) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func onChanged(_ action: @escaping (CGSize) -> Void) -> Self {
        var copy = self
        copy.onChanged = action
        return copy
    }

    func onEnded(_ action: @escaping (CGSize) -> Void) -> Self {
        var copy = self
        copy.onEnded = action
        return copy
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: ((CGSize) -> Void)?
        var onEnded: ((CGSize) -> Void)?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }
            let velocity = panGesture.velocity(in: gestureRecognizer.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
            let size = CGSize(width: translation.x, height: translation.y)
            switch gestureRecognizer.state {
            case .changed:
                onChanged?(size)
            case .ended, .cancelled, .failed:
                onEnded?(size)
            default:
                break
            }
        }
    }
}

@available(iOS 26.0, *)
private struct TestGestureView: View {
    var body: some View {
        Text("Hello")
            .gesture(
                TestHorizontalPanGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
    }
}

@available(iOS 26.0, *)
@objc(TestHorizontalGestureVC)
private class TestHorizontalGestureVC: UIHostingController<TestGestureView> {}

extension SentrySubClassFinderTests {

    func testActOnSubclassesOfViewController_WithAvailabilityGatedGestureClass() {
        // Use the real runtime wrapper (no injected classes) so the finder reads the actual
        // __objc_classlist of the test binary, which contains TestHorizontalPanGesture.Coordinator,
        // an @available(iOS 26.0, *) NSObject subclass whose parent type conforms to
        // UIGestureRecognizerRepresentable. Realizing it (via NSClassFromString) would trigger Swift
        // metadata resolution that can crash on iOS versions where the protocol doesn't exist. The
        // finder must walk its superclass chain (reaching NSObject) without realizing it, so it's
        // skipped as a non-view-controller and never crashes.
        fixture.runtimeWrapper.classes = nil

        let expect = expectation(description: "SubClassFinder callback")
        expect.assertForOverFulfill = false

        var foundClasses: [AnyClass] = []
        let sut = fixture.getSut()
        sut.actOnSubclassesOfViewController(inImage: fixture.imageName) { subClass in
            XCTAssertTrue(Thread.isMainThread)
            foundClasses.append(subClass)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 5)

        // The plain UIViewController subclasses in the test binary are still found, proving the scan
        // completed without crashing on the availability-gated gesture types.
        XCTAssertTrue(foundClasses.contains(where: { $0 == FirstViewController.self }))

        // Reference the gated view controller so its gesture types (including the Coordinator that
        // triggers the crash) are compiled into the test binary and exercised by the scan above.
        if #available(iOS 26.0, *) {
            XCTAssertNotNil(TestHorizontalGestureVC.self)
        }
    }
}

#endif
