@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import MachO
import ObjectiveC
import XCTest

#if os(iOS) || os(tvOS)
class SentrySubClassFinderTests: XCTestCase {
    
    private class Fixture {
        lazy var imageClassProvider: TestImageClassProvider = {
            let result = TestImageClassProvider()
            result.classes = { _ in
                return self.testClasses
            }
            return result
        }()
        let imageName: String
        let dispatchQueue = TestSentryDispatchQueueWrapper()
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
            return SentrySubClassFinder(dispatchQueue: dispatchQueue, imageClassProvider: imageClassProvider, swizzleClassNameExcludes: swizzleClassNameExcludes)
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
        fixture.imageClassProvider.classes = { _ in [] }
        assertActOnSubclassesOfViewController(expected: [])
    }

    func testActOnSubclassesOfViewController_NoViewController_DoesNotDispatchToMainQueue() {
        // Arrange
        fixture.imageClassProvider.classes = { _ in [] }
        let sut = fixture.getSut()

        // Act
        sut.actOnSubclassesOfViewController(inImage: fixture.imageName) { _ in
            XCTFail("Block must not be called when there are no subclasses to swizzle.")
        }

        // Assert
        XCTAssertEqual(fixture.dispatchQueue.blockOnMainInvocations.count, 0)
    }

    func testActOnSubclassesOfViewController_IgnoreFakeViewController() {
        fixture.imageClassProvider.classes = { _ in [FakeViewController.self] }
        assertActOnSubclassesOfViewController(expected: [])
    }

    func testActOnSubclassesOfViewController_WrongImage_NoViewController() {
        fixture.imageClassProvider.classes = { _ in [] }
        assertActOnSubclassesOfViewController(expected: [], imageName: "OtherImage")
    }

    func testGettingSubclasses_DoesNotCallInitializer() throws {
        let trackedClassName = try XCTUnwrap(
            SentryInitializeForGettingSubclassesCalled.registerDynamicClass())
        let trackedClass: AnyClass = try XCTUnwrap(NSClassFromString(trackedClassName))
        fixture.imageClassProvider.classes = { _ in
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
    func testClassesForImage_whenReadingEveryLoadedImage_shouldMatchCopyClassNamesForImage() throws {
        // -- Arrange --
        let sut = SentryDefaultImageClassProvider()
        var comparedImages = 0

        for index in 0..<_dyld_image_count() {
            let imageName = try XCTUnwrap(_dyld_get_image_name(index).map { String(cString: $0) })

            // -- Act --
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

            // -- Assert --
            XCTAssertEqual(fromClassList, fromCopyNames, "Enumeration mismatch for image \(imageName)")
            if !fromCopyNames.isEmpty { comparedImages += 1 }
        }

        // Ensure the comparison actually ran against images that contain classes (e.g. UIKitCore and
        // this test bundle), so the test can't silently pass on empty input.
        XCTAssertGreaterThan(comparedImages, 0, "Expected at least one image with classes")
    }
    
    /// Documents that a class whose superclass chain does not reach `UIViewController` is dropped by
    /// the `class_getSuperclass` filter even when mixed in with real view controllers.
    ///
    /// This covers the weak-linked-missing-superclass shape (objc4 zeroes the superclass → the walk
    /// can't reach `UIViewController`). It does not cover the raw-vs-remapped pointer identity of a
    /// resolved Objective-C future class with a view-controller superclass (Finding 2 in
    /// REVIEW-PR-8457.md, tracked in HANDOFF-subclassfinder-fix.md; see also the known-limitation note
    /// in `SentryDefaultImageClassProvider.classes(forImage:)`); reproducing that needs an ObjC bundle
    /// + `objc_getFutureClass`, which the test suite has no harness for.
    func testActOnSubclassesOfViewController_WhenClassDoesNotReachViewController_IsNotSwizzled() {
        fixture.imageClassProvider.classes = { _ in
            [FakeViewController.self, FirstViewController.self, SecondViewController.self]
        }
        assertActOnSubclassesOfViewController(expected: [FirstViewController.self, SecondViewController.self])
    }

    /// A real dyld-loaded `__objc_classlist` section never contains null entries (dyld binds every
    /// slot at load time), so this edge case can't be produced through `classes(forImage:)`. Instead
    /// we hand the section-parsing helper a crafted buffer shaped exactly like `getsectiondata`'s
    /// return value — pointer-sized `Class _Nullable` entries — with a null slot in the middle, and
    /// assert the null is skipped rather than surfacing as an invalid non-optional `AnyClass`.
    func testClassesInSection_whenSectionContainsNullEntry_shouldSkipIt() {
        // -- Arrange --
        var entries: [AnyClass?] = [FirstViewController.self, nil, SecondViewController.self]

        // -- Act --
        let classes: [AnyClass] = entries.withUnsafeMutableBytes { raw in
            let section = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return SentryDefaultImageClassProvider.classes(inSection: section, size: UInt(raw.count))
        }

        // -- Assert --
        XCTAssertEqual(classes.count, 2)
        XCTAssertTrue(classes[0] == FirstViewController.self)
        XCTAssertTrue(classes[1] == SecondViewController.self)
    }

    /// End-to-end regression test for GH-8152. The other tests inject a fake class list through the
    /// stub provider; this one drives the REAL `SentryDefaultImageClassProvider` through the finder
    /// against this test bundle's image. It proves the production enumeration path — reading the
    /// `__objc_classlist` section and walking `class_getSuperclass` — discovers the bundle's
    /// `UIViewController` subclasses and ignores everything else, end to end.
    ///
    /// `AvailabilityGatedNonViewController` is an `@available`-gated `NSObject` subclass compiled
    /// into the same image, standing in for the real-world crashers (SwiftUI gesture coordinators,
    /// `RoomPlan`/`ActivityKit` wrappers). The old path realized every class here via
    /// `NSClassFromString`; realizing such a gated class on an OS older than its availability is
    /// what crashed in Swift metadata completion. The new path never realizes classes during
    /// discovery, so it can't trigger that. The actual `EXC_BAD_ACCESS` is device- and
    /// OS-version-specific and cannot be reproduced on CI simulators, so this test guards the
    /// enumeration and selection behavior rather than the crash itself.
    func testRealRuntimeWrapper_whenReadingBundleImage_findsBundleViewControllers() throws {
        let realProvider = SentryDefaultImageClassProvider()
        let imageName = try XCTUnwrap(
            class_getImageName(FirstViewController.self).map { String(cString: $0) })

        let sut = SentrySubClassFinder(
            dispatchQueue: TestSentryDispatchQueueWrapper(),
            imageClassProvider: realProvider,
            swizzleClassNameExcludes: [])

        var found: [AnyClass] = []
        sut.actOnSubclassesOfViewController(inImage: imageName) { found.append($0) }

        for expected in [FirstViewController.self, SecondViewController.self,
                         ViewControllerNumberThree.self, VCAnyNaming.self] {
            XCTAssertTrue(found.contains { $0 == expected },
                          "Expected \(expected) to be discovered via the real enumeration path")
        }
        XCTAssertFalse(found.contains { $0 == FakeViewController.self },
                       "Non-UIViewController must not be discovered")
        if #available(iOS 17.0, tvOS 17.0, *) {
            XCTAssertFalse(found.contains { $0 == AvailabilityGatedNonViewController.self },
                           "Availability-gated non-UIViewController must not be discovered")
        }
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

/// Test seam for injecting a fake class list into `SentrySubClassFinder`. The `classes` closure
/// receives the requested image name and returns the classes the finder should see.
private final class TestImageClassProvider: SentryImageClassProvider {
    var classes: (UnsafePointer<CChar>) -> [AnyClass] = { _ in [] }
    func classes(forImage image: UnsafePointer<CChar>) -> [AnyClass] {
        return classes(image)
    }
}

/// An `@available`-gated `NSObject` subclass, standing in for the real-world classes that crashed
/// GH-8152 (SwiftUI gesture coordinators, `RoomPlan`/`ActivityKit` wrappers). It is compiled into
/// the test image's `__objc_classlist` so the enumeration must encounter it without realizing it.
@available(iOS 17.0, tvOS 17.0, *)
class AvailabilityGatedNonViewController: NSObject {}
#endif
