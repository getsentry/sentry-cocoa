import Foundation
@testable import Sentry
import XCTest

class SentryReplayRecordingTests: XCTestCase {
    
    func test_serialize() throws {
        let sut = SentryReplayRecording(segmentId: 3, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: nil)
      
        let data = sut.serialize()
        
        let metaInfo = try XCTUnwrap(data.first)
        let metaInfoData = metaInfo["data"] as? [String: Any]
        
        let recordingInfo = try XCTUnwrap(data.element(at: 1))
        let recordingData = recordingInfo["data"] as? [String: Any]
        let recordingPayload = recordingData?["payload"] as? [String: Any]
        
        XCTAssertEqual(metaInfo["type"] as? Int, 4)
        XCTAssertEqual(metaInfo["timestamp"] as? Int, 2_000)
        XCTAssertEqual(metaInfoData?["href"] as? String, "")
        XCTAssertEqual(metaInfoData?["height"] as? Int, 930)
        XCTAssertEqual(metaInfoData?["width"] as? Int, 390)
        XCTAssertEqual(recordingInfo["type"] as? Int, 5)
        XCTAssertEqual(recordingInfo["timestamp"] as? Int, 2_000)
        XCTAssertEqual(recordingData?["tag"] as? String, "video")
        XCTAssertEqual(recordingPayload?["segmentId"] as? Int, 3)
        XCTAssertEqual(recordingPayload?["size"] as? Int, 200)
        XCTAssertEqual(recordingPayload?["duration"] as? Double, 5_000)
        XCTAssertEqual(recordingPayload?["encoding"] as? String, "h264")
        XCTAssertEqual(recordingPayload?["container"] as? String, "mp4")
        XCTAssertEqual(recordingPayload?["height"] as? Int, 930)
        XCTAssertEqual(recordingPayload?["width"] as? Int, 390)
        XCTAssertEqual(recordingPayload?["frameCount"] as? Int, 5)
        XCTAssertEqual(recordingPayload?["frameRateType"] as? String, "constant")
        XCTAssertEqual(recordingPayload?["frameRate"] as? Int, 1)
        XCTAssertEqual(recordingPayload?["left"] as? Int, 0)
        XCTAssertEqual(recordingPayload?["top"] as? Int, 0)
    }
    
    func test_serializeWithExtra() throws {
        let date = Date(timeIntervalSince1970: 5)
        let sut = SentryReplayRecording(segmentId: 3, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: [
            SentryRRWebEvent(type: .custom, timestamp: date, data: nil)
        ])
      
        let data = sut.serialize()
        
        let extraInfo = try XCTUnwrap(data.element(at: 2))
        XCTAssertEqual(extraInfo["type"] as? Int, 5)
        XCTAssertEqual(extraInfo["timestamp"] as? Int, 5_000)
    }
}
