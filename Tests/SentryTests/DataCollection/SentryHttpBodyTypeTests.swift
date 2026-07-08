@_spi(Private) @testable import Sentry
import XCTest

class SentryHttpBodyTypeTests: XCTestCase {

    func testAll_shouldContainAllFourTypes() {
        let all: SentryDataCollection.HttpBodyType = .all
        XCTAssertTrue(all.contains(.incomingRequest))
        XCTAssertTrue(all.contains(.outgoingRequest))
        XCTAssertTrue(all.contains(.incomingResponse))
        XCTAssertTrue(all.contains(.outgoingResponse))
    }

    func testEmpty_shouldContainNothing() {
        let empty: SentryDataCollection.HttpBodyType = []
        XCTAssertFalse(empty.contains(.incomingRequest))
        XCTAssertFalse(empty.contains(.outgoingRequest))
        XCTAssertFalse(empty.contains(.incomingResponse))
        XCTAssertFalse(empty.contains(.outgoingResponse))
    }

    func testCombination_shouldSupportBitwiseComposition() {
        let combined: SentryDataCollection.HttpBodyType = [.outgoingRequest, .incomingResponse]
        XCTAssertTrue(combined.contains(.outgoingRequest))
        XCTAssertTrue(combined.contains(.incomingResponse))
        XCTAssertFalse(combined.contains(.incomingRequest))
        XCTAssertFalse(combined.contains(.outgoingResponse))
    }

    func testRawValues_shouldBePowersOfTwo() {
        XCTAssertEqual(SentryDataCollection.HttpBodyType.incomingRequest.rawValue, 1 << 0)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.outgoingRequest.rawValue, 1 << 1)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.incomingResponse.rawValue, 1 << 2)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.outgoingResponse.rawValue, 1 << 3)
    }

    // MARK: - Strings Init

    func testInitWithStrings_whenAllKnownValuesArePresent_shouldReturnAllBodyTypes() {
        // -- Arrange --
        let strings = ["incomingRequest", "outgoingRequest", "incomingResponse", "outgoingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .all)
    }

    func testInitWithStrings_whenArrayIsEmpty_shouldReturnEmptyOptionSet() {
        // -- Arrange --
        let strings: [String] = []

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, [])
    }

    func testInitWithStrings_whenUnknownValuesArePresent_shouldIgnoreUnknownValues() {
        // -- Arrange --
        let strings = ["incomingRequest", "unknown"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, [.incomingRequest])
    }
}
