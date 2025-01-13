@testable import Sentry
import XCTest

class SentryTraceOriginTestsTests: XCTestCase {

    /// This test asserts that the constant matches the SDK specification.
    func testAutoNSData_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoNSData, "auto.file.ns_data")
    }

    /// This test asserts that the constant matches the SDK specification.
    func testManualData_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.manualData, "manual.file.data")
    }
}
