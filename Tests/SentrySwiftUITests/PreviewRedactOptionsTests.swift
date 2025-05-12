@testable import SentrySwiftUI
import XCTest

class PreviewRedactOptionsTests: XCTestCase {
    func testInit_whenWithoutArguments_shouldUseDefaultOptions() {
        // -- Act --
        let options = PreviewRedactOptions()

        // -- Assert --
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertTrue(options.maskedViewClasses.isEmpty)
        XCTAssertTrue(options.unmaskedViewClasses.isEmpty)
        XCTAssertTrue(options.enableViewRendererV2)
    }

    func testInit_withAllArguments_shouldSetOptions() {
        // -- Arrange --
        let options = PreviewRedactOptions(
            maskAllText: false,
            maskAllImages: false,
            maskedViewClasses: [UIView.self],
            unmaskedViewClasses: [UIButton.self],
            enableViewRendererV2: true
        )
        // -- Assert --
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        assertEqualClasses(options.maskedViewClasses, [UIView.self])
        assertEqualClasses(options.unmaskedViewClasses, [UIButton.self])
        XCTAssertTrue(options.enableViewRendererV2)
    }

    func testInit_maskAllTextOmitted_shouldUseDefault() {
        // -- Arrange --
        let options = PreviewRedactOptions(
            maskAllImages: true,
            maskedViewClasses: [UIView.self], 
            unmaskedViewClasses: [UIButton.self], 
            enableViewRendererV2: true
        )

        // -- Assert --
        XCTAssertTrue(options.maskAllText)
    }

    func testInit_maskAllImagesOmitted_shouldUseDefault() {
        // -- Arrange --
        let options = PreviewRedactOptions(
            maskAllText: true,
            maskedViewClasses: [UIView.self],
            unmaskedViewClasses: [UIButton.self],
            enableViewRendererV2: true
        )

        // -- Assert --
        XCTAssertTrue(options.maskAllImages)
    }

    func testInit_maskedViewClassesOmitted_shouldUseDefault() {
        // -- Arrange --
        let options = PreviewRedactOptions(
            maskAllText: true,
            maskAllImages: true,
            unmaskedViewClasses: [UIButton.self],
            enableViewRendererV2: true
        )

        // -- Assert --
        XCTAssertTrue(options.maskedViewClasses.isEmpty)
    }

    func testInit_unmaskedViewClassesOmitted_shouldUseDefault() {
        // -- Arrange --
        let options = PreviewRedactOptions(
            maskAllText: true,
            maskAllImages: true,
            maskedViewClasses: [UIView.self],
            enableViewRendererV2: true
        )

        // -- Assert --
        XCTAssertTrue(options.unmaskedViewClasses.isEmpty)
    }

    func testInit_enableViewRendererV2Omitted_shouldUseDefault() {
        // -- Arrange --
        let options = PreviewRedactOptions(
            maskAllText: true,
            maskAllImages: true,
            maskedViewClasses: [UIView.self],
            unmaskedViewClasses: [UIButton.self]
        )

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }

    // MARK: - Assertion Helpers

    fileprivate func assertEqualClasses(_ actual: [AnyClass], _ expected: [AnyClass]) {
        guard actual.count == expected.count else {
            XCTFail("Expected \(expected.count) classes but got \(actual.count) instead")
            return
        }
        for index in 0..<actual.count {
            let expectedClass: AnyClass = expected[index]
            let actualClass: AnyClass = actual[index]
            XCTAssertTrue(
                ObjectIdentifier(actualClass) == ObjectIdentifier(expectedClass),
                "Class at index \(index) doesn't match: expected \(expectedClass), got \(actualClass)"
            )
        }
    }
}
