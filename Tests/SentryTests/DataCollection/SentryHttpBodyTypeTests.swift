@_spi(Private) @testable import Sentry
import XCTest

class SentryHttpBodyTypeTests: XCTestCase {

    func testAll_shouldContainAllFourTypes() throws {
        // -- Act --
        let all: SentryDataCollection.HttpBodyType = .all

        // -- Assert --
        XCTAssertTrue(all.contains(.incomingRequest))
        XCTAssertTrue(all.contains(.outgoingRequest))
        XCTAssertTrue(all.contains(.incomingResponse))
        XCTAssertTrue(all.contains(.outgoingResponse))
    }

    func testEmpty_shouldContainNothing() throws {
        // -- Act --
        let empty: SentryDataCollection.HttpBodyType = []

        // -- Assert --
        XCTAssertFalse(empty.contains(.incomingRequest))
        XCTAssertFalse(empty.contains(.outgoingRequest))
        XCTAssertFalse(empty.contains(.incomingResponse))
        XCTAssertFalse(empty.contains(.outgoingResponse))
    }

    func testCombination_shouldSupportBitwiseComposition() throws {
        // -- Act --
        let combined: SentryDataCollection.HttpBodyType = [.outgoingRequest, .incomingResponse]

        // -- Assert --
        XCTAssertTrue(combined.contains(.outgoingRequest))
        XCTAssertTrue(combined.contains(.incomingResponse))
        XCTAssertFalse(combined.contains(.incomingRequest))
        XCTAssertFalse(combined.contains(.outgoingResponse))
    }

    func testRawValues_shouldBePowersOfTwo() throws {
        // -- Assert --
        XCTAssertEqual(SentryDataCollection.HttpBodyType.incomingRequest.rawValue, 1 << 0)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.outgoingRequest.rawValue, 1 << 1)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.incomingResponse.rawValue, 1 << 2)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.outgoingResponse.rawValue, 1 << 3)
    }

    // MARK: - Strings Init

    func testInitWithStrings_whenAllKnownValuesArePresent_shouldReturnAllBodyTypes() throws {
        // -- Arrange --
        let strings = ["incomingRequest", "outgoingRequest", "incomingResponse", "outgoingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .all)
    }

    func testInitWithStrings_whenIncomingRequestIsPresent_shouldReturnIncomingRequest() throws {
        // -- Arrange --
        let strings = ["incomingRequest"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .incomingRequest)
    }

    func testInitWithStrings_whenOutgoingRequestIsPresent_shouldReturnOutgoingRequest() throws {
        // -- Arrange --
        let strings = ["outgoingRequest"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .outgoingRequest)
    }

    func testInitWithStrings_whenIncomingResponseIsPresent_shouldReturnIncomingResponse() throws {
        // -- Arrange --
        let strings = ["incomingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .incomingResponse)
    }

    func testInitWithStrings_whenOutgoingResponseIsPresent_shouldReturnOutgoingResponse() throws {
        // -- Arrange --
        let strings = ["outgoingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .outgoingResponse)
    }

    func testInitWithStrings_whenArrayIsEmpty_shouldReturnEmptyOptionSet() throws {
        // -- Arrange --
        let strings: [String] = []

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, [])
    }

    func testInitWithStrings_whenUnknownValuesArePresent_shouldIgnoreUnknownValues() throws {
        // -- Arrange --
        let strings = ["incomingRequest", "unknown"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, [.incomingRequest])
    }
}
