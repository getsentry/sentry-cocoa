import XCTest

final class SentryDateUtilsTests: XCTestCase {
    
    func testFromIso8601String_WithEmptyInput_ReturnsNil() {
        XCTAssertNil(sentry_fromIso8601String(""))
    }
    
    func testFromIso8601String_WithInvalidInput_ReturnsNil() {
        XCTAssertNil(sentry_fromIso8601String("not a date"))
    }
    
    func testFromIso8601String_WithMillisecondPrecision_ReturnsCorrectDate() throws {
        // Precalculated date that matches the string below
        let expectedDate = Date(timeIntervalSince1970: 26_269_950.123000026)

        let dateString = "1970-11-01T01:12:30.123Z"
        let date = try XCTUnwrap(sentry_fromIso8601String(dateString))

        XCTAssertEqual(date, expectedDate)
    }
}
