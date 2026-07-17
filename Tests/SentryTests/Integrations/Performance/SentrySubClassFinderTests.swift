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
