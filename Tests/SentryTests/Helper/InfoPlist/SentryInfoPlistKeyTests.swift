@_spi(Private) @testable import Sentry
import XCTest

class SentryInfoPlistKeyTests: XCTestCase {
    func testXcodeVersion_shouldReturnExpectedConstant() {
        XCTAssertEqual(SentryInfoPlistKey.xcodeVersion.rawValue, "DTXcode")
    }

    func testDesignRequiresCompatibility_shouldReturnExpectedConstant() {
        XCTAssertEqual(SentryInfoPlistKey.designRequiresCompatibility.rawValue, "UIDesignRequiresCompatibility")
    }
}
