import Foundation
import XCTest

class SentryReplayEventTests: XCTestCase {
 
    func test_Serialize() {
        let sut = SentryReplayEvent()
        sut.urls = ["Screen 1", "Screen 2"]
        sut.replayStartTimestamp = Date(timeIntervalSince1970: 1)

        let traceIds = [SentryId(), SentryId()]
        sut.traceIds = traceIds
        
        let replayId = SentryId()
        sut.eventId = replayId
        
        sut.segmentId = 3
        
        let result = sut.serialize()
        
        XCTAssertEqual(result["urls"] as? [String], ["Screen 1", "Screen 2"])
        XCTAssertEqual(result["replay_start_timestamp"] as? Int, 1)
        XCTAssertEqual(result["trace_ids"] as? [String], [ traceIds[0].sentryIdString, traceIds[1].sentryIdString])
        XCTAssertEqual(result["replay_id"] as? String, replayId.sentryIdString)
        XCTAssertEqual(result["segment_id"] as? Int, 3)
        XCTAssertEqual(result["replay_type"] as? String, "buffer")
    }
    
}
