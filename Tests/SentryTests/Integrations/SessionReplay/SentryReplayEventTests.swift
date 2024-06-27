import Foundation
@testable import Sentry
import XCTest

class SentryReplayEventTests: XCTestCase {
 
    func test_Serialize() {
        let replayId = SentryId()
        let sut = SentryReplayEvent(eventId: replayId, replayStartTimestamp: Date(timeIntervalSince1970: 1), replayType: .buffer, segmentId: 3)
        sut.urls = ["Screen 1", "Screen 2"]
        
        let result = sut.serialize()
        
        XCTAssertEqual(result["urls"] as? [String], ["Screen 1", "Screen 2"])
        XCTAssertEqual(result["replay_start_timestamp"] as? Double, 1)
        XCTAssertEqual(result["replay_id"] as? String, replayId.sentryIdString)
        XCTAssertEqual(result["segment_id"] as? Int, 3)
        XCTAssertEqual(result["replay_type"] as? String, "buffer")
    }
}
