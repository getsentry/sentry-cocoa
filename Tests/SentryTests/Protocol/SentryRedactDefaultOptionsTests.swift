@_spi(Private) @testable import Sentry
import XCTest

class SentryRedactDefaultOptionsTests: XCTestCase {

    func testDefaultOptions() {
        // -- Act --
        let options = SentryRedactDefaultOptions()

        // -- Assert --
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 0)
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
        // On iOS 26+, CameraUI.ChromeSwiftUIView should be in the ignored set
        #if os(iOS)
        if #available(iOS 26.0, *) {
            XCTAssertEqual(options.viewTypesIgnoredFromSubtreeTraversal.count, 1)
            XCTAssertTrue(options.viewTypesIgnoredFromSubtreeTraversal.contains("CameraUI.ChromeSwiftUIView"), "CameraUI.ChromeSwiftUIView should be ignored by default on iOS 26+")
        } else {
            XCTAssertEqual(options.viewTypesIgnoredFromSubtreeTraversal.count, 0)
        }
        #else
        XCTAssertEqual(options.viewTypesIgnoredFromSubtreeTraversal.count, 0)
        #endif
    }
}
