import Foundation
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentryOnDemandReplayTests: XCTestCase {
    
    private let workingQueue = DispatchQueue(label: "io.sentry.TestQueue")
    
    func getSut() -> SentryOnDemandReplay {
        let outputPath = FileManager.default.temporaryDirectory
        let sut = SentryOnDemandReplay(outputPath: outputPath.path)
        sut.workingQueue = workingQueue
        return sut
    }
    
    func testAddFrame() {
        let sut = getSut()
        sut.addFrameAsync(image: UIImage.add)
       
        waitWorkingQueue()
        
        guard let frame = sut.frames.first else {
            fail("Frame was not saved")
            return
        }
        expect(FileManager.default.fileExists(atPath: frame.imagePath)) == true
    }
    
    func testReleaseFrames() {
        let sut = getSut()
        
        let dateProvider = TestCurrentDateProvider()
        
        sut.dateProvider = dateProvider
        
        for _ in 0..<10 {
            sut.addFrameAsync(image: UIImage.add)
            waitWorkingQueue()
            dateProvider.advance(by: 1)
        }
       
        waitWorkingQueue()
        sut.releaseFramesUntil(dateProvider.date().addingTimeInterval(-5))
        waitWorkingQueue()
        
        expect(sut.frames.count) == 5
        expect(sut.frames.first?.time) == Date(timeIntervalSinceReferenceDate: 5)
        expect(sut.frames.last?.time) == Date(timeIntervalSinceReferenceDate: 9)
    }
    
    func testGenerateVideo() {
        let sut = getSut()
        let dateProvider = TestCurrentDateProvider()
        dateProvider.driftTimeForEveryRead = true
        dateProvider.driftTimeInterval = 1
        sut.dateProvider = dateProvider
        
        for _ in 0..<10 {
            sut.addFrameAsync(image: UIImage.add)
        }
       
        waitWorkingQueue()
        
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
    
    private func waitWorkingQueue() {
        //SentryOnDemandReplay dispatch some of the work to a background queue to avoid race conditions
        //We can use this function to make sure the last called operation is complete.
        let group = DispatchGroup()
        let queueExpected = expectation(description: "Wait for queue to release")
        
        group.enter()
        workingQueue.async {
            queueExpected.fulfill()
            group.leave()
        }
        
        let _ = group.wait(timeout: .now() + 0.1)
        
        wait(for: [queueExpected], timeout: 0.1)
    }
}
#endif
