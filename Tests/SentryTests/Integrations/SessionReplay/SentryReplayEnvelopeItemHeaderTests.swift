import Foundation
import Nimble
import XCTest

class SentryReplayEnvelopeItemHeaderTests: XCTestCase {
   
    func testInitWithTypeSegmentIdLength() {
         let header = SentryReplayEnvelopeItemHeader(type: "testType", segmentId: 1, length: 100)
         
         expect(header.type) == "testType"
         expect(header.segmentId) == 1
         expect(header.length) == 100
     }
     
     func testReplayRecordingHeader() {
         let header = SentryReplayEnvelopeItemHeader.replayRecordingHeader(withSegmentId: 2, length: 200)
         
         expect(header.type) == SentryEnvelopeItemTypeReplayRecording
         expect(header.segmentId) == 2
         expect(header.length) == 200
     }
     
     func testReplayVideoHeader() {
         let header = SentryReplayEnvelopeItemHeader.replayVideoHeader(withSegmentId: 3, length: 300)
         
         expect(header.type) == SentryEnvelopeItemTypeReplayVideo
         expect(header.segmentId) == 3
         expect(header.length) == 300
     }
     
     func testSerialize() {
         let header = SentryReplayEnvelopeItemHeader(type: "testType", segmentId: 4, length: 400)
         let serialized = header.serialize()
         
         expect(serialized["type"] as? String) == "testType"
         expect(serialized["length"] as? Int) == 400
         expect(serialized["segment_id"] as? Int) == 4
     }
    
    func testEnvelopeItemHeaderType() {
        expect(SentryEnvelopeItemTypeReplayVideo) == "replay_video"
        expect(SentryEnvelopeItemTypeReplayRecording) == "replay_recording"
    }
}
