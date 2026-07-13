@testable import Sentry
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
}
