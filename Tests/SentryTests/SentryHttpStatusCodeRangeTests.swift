import XCTest

class SentryHttpStatusCodeRangeTests: XCTestCase {

    // MARK: - Init Properties

    func testInit_whenMinAndMax_shouldSetProperties() {
        let range = HttpStatusCodeRange(min: 400, max: 499)

        XCTAssertEqual(range.min, 400)
        XCTAssertEqual(range.max, 499)
    }

    func testInit_whenStatusCode_shouldSetMinAndMaxEqual() {
        let range = HttpStatusCodeRange(statusCode: 500)

        XCTAssertEqual(range.min, 500)
        XCTAssertEqual(range.max, 500)
    }

    // MARK: - Range Init: isInRange

    func testIsInRange_whenStatusCodeWithinRange_shouldReturnTrue() {
        let range = HttpStatusCodeRange(min: 500, max: 599)

        XCTAssertTrue(range.is(inRange: 550))
    }

    func testIsInRange_whenStatusCodeEqualsMin_shouldReturnTrue() {
        let range = HttpStatusCodeRange(min: 500, max: 599)

        XCTAssertTrue(range.is(inRange: 500))
    }

    func testIsInRange_whenStatusCodeEqualsMax_shouldReturnTrue() {
        let range = HttpStatusCodeRange(min: 500, max: 599)

        XCTAssertTrue(range.is(inRange: 599))
    }

    func testIsInRange_whenStatusCodeBelowMin_shouldReturnFalse() {
        let range = HttpStatusCodeRange(min: 500, max: 599)

        XCTAssertFalse(range.is(inRange: 499))
    }

    func testIsInRange_whenStatusCodeAboveMax_shouldReturnFalse() {
        let range = HttpStatusCodeRange(min: 500, max: 599)

        XCTAssertFalse(range.is(inRange: 600))
    }

    func testIsInRange_whenMinEqualsMax_shouldMatchOnlyThatCode() {
        let range = HttpStatusCodeRange(min: 500, max: 500)

        XCTAssertTrue(range.is(inRange: 500))
        XCTAssertFalse(range.is(inRange: 499))
        XCTAssertFalse(range.is(inRange: 501))
    }

    // The init does not validate min <= max, so an inverted range matches nothing.
    func testIsInRange_whenMinGreaterThanMax_shouldAlwaysReturnFalse() {
        let range = HttpStatusCodeRange(min: 599, max: 500)

        XCTAssertFalse(range.is(inRange: 500))
        XCTAssertFalse(range.is(inRange: 550))
        XCTAssertFalse(range.is(inRange: 599))
    }

    // MARK: - StatusCode Init: isInRange

    func testIsInRange_whenStatusCodeInitAndExactMatch_shouldReturnTrue() {
        let range = HttpStatusCodeRange(statusCode: 500)

        XCTAssertTrue(range.is(inRange: 500))
    }

    func testIsInRange_whenStatusCodeInitAndDifferentCode_shouldReturnFalse() {
        let range = HttpStatusCodeRange(statusCode: 500)

        XCTAssertFalse(range.is(inRange: 501))
    }
}
