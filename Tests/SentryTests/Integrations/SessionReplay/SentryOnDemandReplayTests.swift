import Foundation
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentryOnDemandReplayTests: XCTestCase {
    
    let dateProvider = TestCurrentDateProvider()
    let outputPath = FileManager.default.temporaryDirectory
    
    func getSut() -> SentryOnDemandReplay {
        let sut = SentryOnDemandReplay(outputPath: outputPath.path, 
                                       workingQueue: TestSentryDispatchQueueWrapper(),
                                       dateProvider: dateProvider)
        return sut
    }
    
    func testAddFrame() {
        let sut = getSut()
        sut.addFrameAsync(image: UIImage.add)
       
        guard let frame = sut.frames.first else {
            fail("Frame was not saved")
            return
        }
        
        expect(FileManager.default.fileExists(atPath: frame.imagePath)) == true
        expect(frame.imagePath.hasPrefix(self.outputPath.path)) == true
    }
    
    func testReleaseFrames() {
        let sut = getSut()
        
        for _ in 0..<10 {
            sut.addFrameAsync(image: UIImage.add)
            dateProvider.advance(by: 1)
        }
       
        sut.releaseFramesUntil(dateProvider.date().addingTimeInterval(-5))
        
        let frames = sut.frames
        
        expect(frames.count) == 5
        expect(frames.first?.time) == Date(timeIntervalSinceReferenceDate: 5)
        expect(frames.last?.time) == Date(timeIntervalSinceReferenceDate: 9)
    }
    
    func testGenerateVideo() {
        let sut = getSut()
        dateProvider.driftTimeForEveryRead = true
        dateProvider.driftTimeInterval = 1
        
        for _ in 0..<10 {
            sut.addFrameAsync(image: UIImage.add)
        }
        
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("video.mp4")
        let videoExpectation = expectation(description: "Wait for video render")
        
        try? sut.createVideoWith(duration: 10, beginning: Date(timeIntervalSinceReferenceDate: 0), outputFileURL: output) { info, error in
            expect(error) == nil
            
            expect(info?.duration) == 10
            expect(info?.start) == Date(timeIntervalSinceReferenceDate: 0)
            expect(info?.end) == Date(timeIntervalSinceReferenceDate: 10)
            
            expect(FileManager.default.fileExists(atPath: output.path)) == true
            videoExpectation.fulfill()
            try? FileManager.default.removeItem(at: output)
        }
        
        wait(for: [videoExpectation], timeout: 1)
    }
    
    func testAddFrameIsThreadSafe() {
        let queue = SentryDispatchQueueWrapper()
        let sut = SentryOnDemandReplay(outputPath: outputPath.path,
                                       workingQueue: queue,
                                       dateProvider: dateProvider)
        
        dateProvider.driftTimeForEveryRead = true
        dateProvider.driftTimeInterval = 1
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                sut.addFrameAsync(image: UIImage.add)
                group.leave()
            }
        }
        
        group.wait()
        queue.queue.sync {} //Wait for all enqueued operation to finish
        expect(sut.frames.map({ ($0.imagePath as NSString).lastPathComponent })) == (0..<10).map { "\($0).png" }
    }
    
    func testReleaseIsThreadSafe() {
        let queue = SentryDispatchQueueWrapper()
        let sut = SentryOnDemandReplay(outputPath: outputPath.path,
                                       workingQueue: queue,
                                       dateProvider: dateProvider)
                
        sut.frames = (0..<100).map { SentryReplayFrame(imagePath: outputPath.path + "/\($0).png", time: Date(timeIntervalSinceReferenceDate: Double($0))) }
                
        let group = DispatchGroup()
        
        for i in 1...10 {
            group.enter()
            DispatchQueue.global().async {
                sut.releaseFramesUntil(Date(timeIntervalSinceReferenceDate: Double(i) * 10.0))
                group.leave()
            }
        }
        
        group.wait()
        
        queue.queue.sync {} //Wait for all enqueued operation to finish
        expect(sut.frames.count) == 0
    }
    
}
#endif
