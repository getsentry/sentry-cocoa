@_spi(Private) @testable import Sentry
import XCTest

class SentryHttpBodyTypeTests: XCTestCase {

    func testAll_shouldContainAllFourTypes() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let all: SentryDataCollection.HttpBodyType = .all

        // -- Assert --
        XCTAssertTrue(all.contains(.incomingRequest))
        XCTAssertTrue(all.contains(.outgoingRequest))
        XCTAssertTrue(all.contains(.incomingResponse))
        XCTAssertTrue(all.contains(.outgoingResponse))
        #endif
    }

    func testEmpty_shouldContainNothing() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let empty: SentryDataCollection.HttpBodyType = []

        // -- Assert --
        XCTAssertFalse(empty.contains(.incomingRequest))
        XCTAssertFalse(empty.contains(.outgoingRequest))
        XCTAssertFalse(empty.contains(.incomingResponse))
        XCTAssertFalse(empty.contains(.outgoingResponse))
        #endif
    }

    func testCombination_shouldSupportBitwiseComposition() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let combined: SentryDataCollection.HttpBodyType = [.outgoingRequest, .incomingResponse]

        // -- Assert --
        XCTAssertTrue(combined.contains(.outgoingRequest))
        XCTAssertTrue(combined.contains(.incomingResponse))
        XCTAssertFalse(combined.contains(.incomingRequest))
        XCTAssertFalse(combined.contains(.outgoingResponse))
        #endif
    }

    func testRawValues_shouldBePowersOfTwo() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Assert --
        XCTAssertEqual(SentryDataCollection.HttpBodyType.incomingRequest.rawValue, 1 << 0)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.outgoingRequest.rawValue, 1 << 1)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.incomingResponse.rawValue, 1 << 2)
        XCTAssertEqual(SentryDataCollection.HttpBodyType.outgoingResponse.rawValue, 1 << 3)
        #endif
    }

    // MARK: - Strings Init

    func testInitWithStrings_whenAllKnownValuesArePresent_shouldReturnAllBodyTypes() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let strings = ["incomingRequest", "outgoingRequest", "incomingResponse", "outgoingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .all)
        #endif
    }

    func testInitWithStrings_whenIncomingRequestIsPresent_shouldReturnIncomingRequest() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let strings = ["incomingRequest"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .incomingRequest)
        #endif
    }

    func testInitWithStrings_whenOutgoingRequestIsPresent_shouldReturnOutgoingRequest() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let strings = ["outgoingRequest"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .outgoingRequest)
        #endif
    }

    func testInitWithStrings_whenIncomingResponseIsPresent_shouldReturnIncomingResponse() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let strings = ["incomingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .incomingResponse)
        #endif
    }

    func testInitWithStrings_whenOutgoingResponseIsPresent_shouldReturnOutgoingResponse() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let strings = ["outgoingResponse"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, .outgoingResponse)
        #endif
    }

    func testInitWithStrings_whenArrayIsEmpty_shouldReturnEmptyOptionSet() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let strings: [String] = []

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, [])
        #endif
    }

    func testInitWithStrings_whenUnknownValuesArePresent_shouldIgnoreUnknownValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let strings = ["incomingRequest", "unknown"]

        // -- Act --
        let bodyTypes = SentryDataCollection.HttpBodyType(strings: strings)

        // -- Assert --
        XCTAssertEqual(bodyTypes, [.incomingRequest])
        #endif
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
