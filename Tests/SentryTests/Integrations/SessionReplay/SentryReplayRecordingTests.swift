import Foundation
import Nimble
import XCTest

class SentryReplayRecordingTests: XCTestCase {
    
    func test_serialize() {
        let sut = SentryReplayRecording(segmentId: 3, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390)
      
        let data = sut.serialize()
        
        let metaInfo = data[0]
        let metaInfoData = metaInfo["data"] as? [String: Any]
        
        let recordingInfo = data[1]
        let recordingData = recordingInfo["data"] as? [String: Any]
        let recordingPayload = recordingData?["payload"] as? [String: Any]
        
        expect(metaInfo["type"] as? Int) == 4
        expect(metaInfo["timestamp"] as? Int) == 2_000
        expect(metaInfoData?["href"] as? String) == ""
        expect(metaInfoData?["height"] as? Int) == 930
        expect(metaInfoData?["width"] as? Int) == 390
        
        expect(recordingInfo["type"] as? Int) == 5
        expect(recordingInfo["timestamp"] as? Int) == 2_000
        expect(recordingData?["tag"] as? String) == "video"
        expect(recordingPayload?["segmentId"] as? Int) == 3
        expect(recordingPayload?["size"] as? Int) == 200
        expect(recordingPayload?["duration"] as? Int) == 5_000
        expect(recordingPayload?["encoding"] as? String) == "h264"
        expect(recordingPayload?["container"] as? String) == "mp4"
        expect(recordingPayload?["height"] as? Int) == 930
        expect(recordingPayload?["width"] as? Int) == 390
        expect(recordingPayload?["frameCount"] as? Int) == 5
        expect(recordingPayload?["frameRateType"] as? String) == "constant"
        expect(recordingPayload?["frameRate"] as? Int) == 1
        expect(recordingPayload?["left"] as? Int) == 0
        expect(recordingPayload?["top"] as? Int) == 0
    }
}
