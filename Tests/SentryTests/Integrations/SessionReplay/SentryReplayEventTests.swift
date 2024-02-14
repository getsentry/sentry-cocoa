import Foundation
import Nimble
import XCTest

class SentryReplayEventTests: XCTestCase {
 
    func test_Serialize() {
        let sut = SentryReplayEvent()
        sut.urls = ["Screen 1", "Screen 2"]
        sut.replayStartTimestamp = Date(timeIntervalSince1970: 1)

        let traceIds = [SentryId(), SentryId()]
        sut.traceIds = traceIds
        
        let replayId = SentryId()
        sut.replayId = replayId
        
        sut.segmentId = 3
        
        let result = sut.serialize()
        
        expect(result["urls"] as? [String]) == ["Screen 1", "Screen 2"]
        expect(result["replay_start_timestamp"] as? Int) == 1_000
        expect(result["trace_ids"] as? [String]) == [ traceIds[0].sentryIdString, traceIds[1].sentryIdString]
        expect(result["replay_id"] as? String) == replayId.sentryIdString
        expect(result["segment_id"] as? Int) == 3
        expect(result["replay_type"] as? String) == "buffer"
    }
    
}
