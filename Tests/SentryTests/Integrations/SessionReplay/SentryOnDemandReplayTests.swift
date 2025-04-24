import CoreMedia
import Foundation
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentryOnDemandReplayTests: XCTestCase {
    
    private let dateProvider = TestCurrentDateProvider()
    private var outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("replayTest")
    
    override func setUpWithError() throws {
        try removeDirectoryIfExists(at: outputPath)
        try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try removeDirectoryIfExists(at: outputPath)
    }
    
    private func removeDirectoryIfExists(at path: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
        }
    }
    
    private func getSut(trueDispatchQueueWrapper: Bool = false) -> SentryOnDemandReplay {
        return SentryOnDemandReplay(outputPath: outputPath.path,
                                    workingQueue: trueDispatchQueueWrapper ? SentryDispatchQueueWrapper() : TestSentryDispatchQueueWrapper(),
                                    dateProvider: dateProvider)
    }
    
    func testAddFrame() {
        let sut = getSut()
        sut.addFrameAsync(image: UIImage.add)
       
        guard let frame = sut.frames.first else {
            XCTFail("Frame was not saved")
            return
        }
        
        XCTAssertEqual(FileManager.default.fileExists(atPath: frame.imagePath), true)
        XCTAssertEqual(frame.imagePath.hasPrefix(self.outputPath.path), true)
    }
    
    func testReleaseFrames() {
        let sut = getSut()
        
        for _ in 0..<10 {
            sut.addFrameAsync(image: UIImage.add)
            dateProvider.advance(by: 1)
        }
       
        sut.releaseFramesUntil(dateProvider.date().addingTimeInterval(-5))
        
        let frames = sut.frames
        
        XCTAssertEqual(frames.count, 5)
        XCTAssertEqual(frames.first?.time, Date(timeIntervalSinceReferenceDate: 5))
        XCTAssertEqual(frames.last?.time, Date(timeIntervalSinceReferenceDate: 9))
    }
    
    func testFramesWithScreenName() {
        let sut = getSut()
        
        for i in 0..<4 {
            sut.addFrameAsync(image: UIImage.add, forScreen: "\(i)")
            dateProvider.advance(by: 1)
        }
        
        sut.releaseFramesUntil(dateProvider.date().addingTimeInterval(-5))
        
        let frames = sut.frames
        
        for i in 0..<4 {
            XCTAssertEqual(frames[i].screenName, "\(i)")
        }
    }
    
    func testGenerateVideo() throws {
        let sut = getSut()
        dateProvider.driftTimeForEveryRead = true
        dateProvider.driftTimeInterval = 1
        
        for _ in 0..<10 {
            sut.addFrameAsync(image: UIImage.add)
        }
        
        let videoExpectation = expectation(description: "Wait for video render")
        
        let videos = try sut.createVideoWith(beginning: Date(timeIntervalSinceReferenceDate: 0), end: Date(timeIntervalSinceReferenceDate: 10))
        XCTAssertEqual(videos.count, 1)
        let info = try XCTUnwrap(videos.first)
        
        XCTAssertEqual(info.duration, 10)
        XCTAssertEqual(info.start, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(info.end, Date(timeIntervalSinceReferenceDate: 10))
        
        let videoPath = info.path
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: videoPath.path))
        
        videoExpectation.fulfill()
        try FileManager.default.removeItem(at: videoPath)
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
        XCTAssertEqual(sut.frames.map({ ($0.imagePath as NSString).lastPathComponent }), (0..<10).map { "\($0).0.png" })
    }
    
    func testReleaseIsThreadSafe() {
        let queue = SentryDispatchQueueWrapper()
        let sut = SentryOnDemandReplay(outputPath: outputPath.path,
                                       workingQueue: queue,
                                       dateProvider: dateProvider)
                
        sut.frames = (0..<100).map { SentryReplayFrame(imagePath: outputPath.path + "/\($0).png", time: Date(timeIntervalSinceReferenceDate: Double($0)), screenName: nil) }
                
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
        XCTAssertEqual(sut.frames.count, 0)
    }
    
    func testInvalidWriter() throws {
        let queue = TestSentryDispatchQueueWrapper()
        let sut = SentryOnDemandReplay(outputPath: outputPath.path,
                                       workingQueue: queue,
                                       dateProvider: dateProvider)
        
        let start = dateProvider.date()
        sut.addFrameAsync(image: UIImage.add)
        dateProvider.advance(by: 1)
        let end = dateProvider.date()
        
        //Creating a file where the replay would be written to cause an error in the writer
        try Data("tempFile".utf8).write(to: outputPath.appendingPathComponent("0.0.mp4"))
        
        XCTAssertThrowsError(try sut.createVideoWith(beginning: start, end: end))
    }
    
    func testGenerateVideoForEachSize() throws {
        let sut = getSut()
        dateProvider.driftTimeForEveryRead = true
        dateProvider.driftTimeInterval = 1
        
        let image1 = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 19)).image { _ in }
        let image2 = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { _ in }
        
        for i in 0..<10 {
            sut.addFrameAsync(image: i < 5 ? image1 : image2)
        }
        
        let videos = try sut.createVideoWith(beginning: Date(timeIntervalSinceReferenceDate: 0), end: Date(timeIntervalSinceReferenceDate: 10))
        
        XCTAssertEqual(videos.count, 2)
        
        let firstVideo = try XCTUnwrap(videos.first)
        let secondVideo = try XCTUnwrap(videos.last)
        
        XCTAssertEqual(firstVideo.duration, 5)
        XCTAssertEqual(secondVideo.duration, 5)
        
        XCTAssertEqual(firstVideo.start, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(secondVideo.start, Date(timeIntervalSinceReferenceDate: 5))
        
        XCTAssertEqual(firstVideo.end, Date(timeIntervalSinceReferenceDate: 5))
        XCTAssertEqual(secondVideo.end, Date(timeIntervalSinceReferenceDate: 10))
        
        XCTAssertEqual(firstVideo.width, 20)
        XCTAssertEqual(firstVideo.height, 19)
        
        XCTAssertEqual(secondVideo.width, 20)
        XCTAssertEqual(secondVideo.height, 10)
    }

    func testCalculatePresentationTime_withOneFPS_shouldReturnTiming() {
        // -- Arrange --
        let framesPerSecond = 1

        // -- Act --
        let zeroIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 0, frameRate: framesPerSecond)
        let firstIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 1, frameRate: framesPerSecond)
        let secondIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 2, frameRate: framesPerSecond)
        let largeIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 1_337, frameRate: framesPerSecond)

        // -- Assert --
        XCTAssertEqual(zeroIndexTime.timeValue.value, 0)
        XCTAssertEqual(zeroIndexTime.timeValue.timescale, 1)
        XCTAssertEqual(zeroIndexTime.timeValue.seconds, 0)

        XCTAssertEqual(firstIndexTime.timeValue.value, 1)
        XCTAssertEqual(firstIndexTime.timeValue.timescale, 1)
        XCTAssertEqual(firstIndexTime.timeValue.seconds, 1)

        XCTAssertEqual(secondIndexTime.timeValue.value, 2)
        XCTAssertEqual(secondIndexTime.timeValue.timescale, 1)
        XCTAssertEqual(secondIndexTime.timeValue.seconds, 2)

        XCTAssertEqual(largeIndexTime.timeValue.value, 1_337)
        XCTAssertEqual(largeIndexTime.timeValue.timescale, 1)
        XCTAssertEqual(largeIndexTime.timeValue.seconds, 1_337)
    }

    func testCalculatePresentationTime_withMoreThanOneFPS_shouldReturnTiming() {
        // -- Arrange --
        let framesPerSecond = 4

        // -- Act --
        let zeroIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 0, frameRate: framesPerSecond)
        let firstIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 1, frameRate: framesPerSecond)
        let secondIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 2, frameRate: framesPerSecond)
        let largeIndexTime = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 1_337, frameRate: framesPerSecond)

        // -- Assert --
        XCTAssertEqual(zeroIndexTime.timeValue.value, 0)
        XCTAssertEqual(zeroIndexTime.timeValue.timescale, 4)
        XCTAssertEqual(zeroIndexTime.timeValue.seconds, 0)

        XCTAssertEqual(firstIndexTime.timeValue.value, 1)
        XCTAssertEqual(firstIndexTime.timeValue.timescale, 4)
        XCTAssertEqual(firstIndexTime.timeValue.seconds, 0.25)

        XCTAssertEqual(secondIndexTime.timeValue.value, 2)
        XCTAssertEqual(secondIndexTime.timeValue.timescale, 4)
        XCTAssertEqual(secondIndexTime.timeValue.seconds, 0.5)

        XCTAssertEqual(largeIndexTime.timeValue.value, 1_337)
        XCTAssertEqual(largeIndexTime.timeValue.timescale, 4)
        XCTAssertEqual(largeIndexTime.timeValue.seconds, 334.25)
    }

    func testCalculatePresentationTime_withNegativeFPS_shouldReturnInvalidTime() {
        // -- Arrange --
        let framesPerSecond = -4

        // -- Act --
        let time = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: 3, frameRate: framesPerSecond)

        // -- Assert --
        XCTAssertFalse(time.timeValue.isValid)
    }

    func testCalculatePresentationTime_withNegativeIndex_shouldReturnNegativeTime() {
        // -- Arrange --
        let framesPerSecond = 4

        // -- Act --
        let time = SentryOnDemandReplay.calculatePresentationTime(forFrameAtIndex: -3, frameRate: framesPerSecond)

        // -- Assert --
        XCTAssertEqual(time.timeValue.value, -3)
        XCTAssertEqual(time.timeValue.timescale, 4)
        XCTAssertEqual(time.timeValue.seconds, -0.75)
    }
}
#endif
