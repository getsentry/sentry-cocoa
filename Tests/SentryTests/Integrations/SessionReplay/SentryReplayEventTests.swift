import Foundation
import Nimble
import XCTest
@testable import Sentry

class SentryReplayEventTests: XCTestCase {
 
    func test_Serialize() {
        let replayId = SentryId()
        let sut = SentryReplayEvent(eventId: replayId, replayStartTimestamp: Date(timeIntervalSince1970: 1), replayType: .buffer, segmentId: 3)
        sut.urls = ["Screen 1", "Screen 2"]
        
        let result = sut.serialize()
        
        expect(result["urls"] as? [String]) == ["Screen 1", "Screen 2"]
        expect(result["replay_start_timestamp"] as? Double) == 1
        expect(result["replay_id"] as? String) == replayId.sentryIdString
        expect(result["segment_id"] as? Int) == 3
        expect(result["replay_type"] as? String) == "buffer"
    }
    
}
