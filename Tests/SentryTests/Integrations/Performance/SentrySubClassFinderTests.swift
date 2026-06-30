import ObjectiveC
@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if canImport(SwiftUI)
import SwiftUI
#endif

#if os(iOS) || os(tvOS)
class SentrySubClassFinderTests: XCTestCase {
    
    private class Fixture {
        lazy var runtimeWrapper: SentryTestObjCRuntimeWrapper = {
            let result = SentryTestObjCRuntimeWrapper()
            result.classesNames = { _ in
                return self.testClassesNames
            }
            return result
        }()
        let imageName: String
        let testClassesNames = [NSStringFromClass(FirstViewController.self),
                                NSStringFromClass(SecondViewController.self),
                                NSStringFromClass(ViewControllerNumberThree.self),
                                NSStringFromClass(VCAnyNaming.self),
                                NSStringFromClass(FakeViewController.self)]
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
        fixture.runtimeWrapper.classesNames = { _ in [] }
        assertActOnSubclassesOfViewController(expected: [])
    }
    
    func testActOnSubclassesOfViewController_IgnoreFakeViewController() {
        fixture.runtimeWrapper.classesNames = { _ in [NSStringFromClass(FakeViewController.self)] }
        assertActOnSubclassesOfViewController(expected: [])
    }
     
    func testActOnSubclassesOfViewController_WrongImage_NoViewController() {
        fixture.runtimeWrapper.classesNames = nil
        assertActOnSubclassesOfViewController(expected: [], imageName: "OtherImage")
    }
  
    func testGettingSubclasses_DoesNotCallInitializer() throws {
        let trackedClassName = try XCTUnwrap(
            SentryInitializeForGettingSubclassesCalled.registerDynamicClass())
        fixture.runtimeWrapper.classesNames = { _ in
            return self.fixture.testClassesNames + [trackedClassName]
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
// When SubClassFinder calls NSClassFromString on it, Swift metadata resolution
// triggers protocol conformance lookup for UIGestureRecognizerRepresentable.
// On iOS versions where the protocol doesn't exist, this crashes.

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
        // Use real ObjC runtime class list — the test binary contains
        // TestHorizontalPanGesture.Coordinator, an @available(iOS 26.0, *)
        // NSObject subclass whose parent type conforms to
        // UIGestureRecognizerRepresentable. NSClassFromString on the
        // Coordinator triggers Swift metadata resolution that can crash
        // on iOS versions where the protocol doesn't exist.
        fixture.runtimeWrapper.classesNames = nil

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

        XCTAssertTrue(foundClasses.contains(where: { $0 == FirstViewController.self }))

        if #available(iOS 26.0, *) {
            XCTAssertTrue(foundClasses.contains(where: { $0 == TestHorizontalGestureVC.self }))
        }
    }
}

#endif
