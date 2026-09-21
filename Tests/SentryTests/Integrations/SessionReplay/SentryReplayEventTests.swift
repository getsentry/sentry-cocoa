@_spi(Private) @testable import Sentry
import Foundation
import XCTest

class SentryReplayEventTests: XCTestCase {
 
    func test_Serialize() {
        // -- Arrange --
        let replayId = SentryId()
        let sut = SentryReplayEvent(eventId: replayId, replayStartTimestamp: Date(timeIntervalSince1970: 1), replayType: .buffer, segmentId: 3)
        sut.urls = ["Screen 1", "Screen 2"]

        // -- Act --
        let result = sut.serialize()

        // -- Assert --
        XCTAssertEqual(result["urls"] as? [String], ["Screen 1", "Screen 2"])
        XCTAssertEqual(result["replay_start_timestamp"] as? Double, 1)
        XCTAssertEqual(result["replay_id"] as? String, replayId.sentryIdString)
        XCTAssertEqual(result["segment_id"] as? Int, 3)
        XCTAssertEqual(result["replay_type"] as? String, "buffer")
    }

    func testSerialize_whenTraceIdsSet_shouldIncludeTraceIds() {
        // -- Arrange --
        let sut = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(timeIntervalSince1970: 1), replayType: .buffer, segmentId: 0)
        let traceIds = [SentryId().sentryIdString, SentryId().sentryIdString]
        sut.traceIds = traceIds

        // -- Act --
        let result = sut.serialize()

        // -- Assert --
        XCTAssertEqual(result["trace_ids"] as? [String], traceIds)
    }

    func testSerialize_whenTraceIdsNil_shouldOmitTraceIds() {
        // -- Arrange --
        let sut = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(timeIntervalSince1970: 1), replayType: .buffer, segmentId: 0)

        // -- Act --
        let result = sut.serialize()

        // -- Assert --
        XCTAssertNil(result["trace_ids"])
    }

    func testSerialize_whenTraceIdsEmpty_shouldOmitTraceIds() {
        // -- Arrange --
        let sut = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(timeIntervalSince1970: 1), replayType: .buffer, segmentId: 0)
        sut.traceIds = []

        // -- Act --
        let result = sut.serialize()

        // -- Assert --
        XCTAssertNil(result["trace_ids"])
    }
}
