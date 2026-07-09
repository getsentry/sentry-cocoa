@_spi(Private) @testable import Sentry
import XCTest

class SentryHttpBodyTypeTests: XCTestCase {

    func testAll_shouldContainAllFourTypes() {
        // -- Act --
        let all: SentryDataCollection.HttpBodyType = .all

        // -- Assert --
        XCTAssertTrue(all.contains(.incomingRequest))
        XCTAssertTrue(all.contains(.outgoingRequest))
        XCTAssertTrue(all.contains(.incomingResponse))
        XCTAssertTrue(all.contains(.outgoingResponse))
    }

    func testEmpty_shouldContainNothing() {
        // -- Act --
        let empty: SentryDataCollection.HttpBodyType = []

        // -- Assert --
        XCTAssertFalse(empty.contains(.incomingRequest))
        XCTAssertFalse(empty.contains(.outgoingRequest))
        XCTAssertFalse(empty.contains(.incomingResponse))
        XCTAssertFalse(empty.contains(.outgoingResponse))
    }

    func testCombination_shouldSupportBitwiseComposition() {
        // -- Act --
        let combined: SentryDataCollection.HttpBodyType = [.outgoingRequest, .incomingResponse]

        // -- Assert --
        XCTAssertTrue(combined.contains(.outgoingRequest))
        XCTAssertTrue(combined.contains(.incomingResponse))
        XCTAssertFalse(combined.contains(.incomingRequest))
        XCTAssertFalse(combined.contains(.outgoingResponse))
    }

    func testRawValues_shouldBePowersOfTwo() {
        // -- Assert --
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

    func testInitWithStrings_whenIncomingRequestIsPresent_shouldReturnIncomingRequest() {
        // -- Arrange --
        let strings = ["incomingRequest"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .incomingRequest)
    }

    func testInitWithStrings_whenOutgoingRequestIsPresent_shouldReturnOutgoingRequest() {
        // -- Arrange --
        let strings = ["outgoingRequest"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .outgoingRequest)
    }

    func testInitWithStrings_whenIncomingResponseIsPresent_shouldReturnIncomingResponse() {
        // -- Arrange --
        let strings = ["incomingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .incomingResponse)
    }

    func testInitWithStrings_whenOutgoingResponseIsPresent_shouldReturnOutgoingResponse() {
        // -- Arrange --
        let strings = ["outgoingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .outgoingResponse)
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
