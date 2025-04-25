import AVFoundation
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
        return SentryOnDemandReplay(
            outputPath: outputPath.path,
            processingQueue: trueDispatchQueueWrapper ? SentryDispatchQueueWrapper() : TestSentryDispatchQueueWrapper(),
            assetWorkerQueue: trueDispatchQueueWrapper ? SentryDispatchQueueWrapper() : TestSentryDispatchQueueWrapper(),
            dateProvider: dateProvider
        )
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
        let processingQueue = SentryDispatchQueueWrapper()
        let workerQueue = SentryDispatchQueueWrapper()
        let sut = SentryOnDemandReplay(
            outputPath: outputPath.path,
            processingQueue: processingQueue,
            assetWorkerQueue: workerQueue,
            dateProvider: dateProvider
        )

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
        processingQueue.queue.sync {} // Wait for all enqueued operation to finish
        XCTAssertEqual(sut.frames.map({ ($0.imagePath as NSString).lastPathComponent }), (0..<10).map { "\($0).0.png" })
    }
    
    func testReleaseIsThreadSafe() {
        let processingQueue = SentryDispatchQueueWrapper()
        let workerQueue = SentryDispatchQueueWrapper()
        let sut = SentryOnDemandReplay(
            outputPath: outputPath.path,
            processingQueue: processingQueue,
            assetWorkerQueue: workerQueue,
            dateProvider: dateProvider
        )

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
        
        processingQueue.queue.sync {} //Wait for all enqueued operation to finish
        XCTAssertEqual(sut.frames.count, 0)
    }
    
    func testInvalidWriter() throws {
        // -- Arrange --
        let processingQueue = SentryDispatchQueueWrapper()
        let workerQueue = SentryDispatchQueueWrapper()
        let sut = SentryOnDemandReplay(
            outputPath: outputPath.path,
            processingQueue: processingQueue,
            assetWorkerQueue: workerQueue,
            dateProvider: dateProvider
        )

        let start = dateProvider.date()
        sut.addFrameAsync(image: UIImage.add)
        dateProvider.advance(by: 1)
        let end = dateProvider.date()
        
        // Creating a file where the replay would be written to cause an error in the writer
        try Data("tempFile".utf8).write(to: outputPath.appendingPathComponent("0.0.mp4"))

        // -- Act & Assert --
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

    func testGenerateVideoInfo_whenNoFramesAdded_shouldNotThrowError() throws {
        // -- Arrange --
        let sut = getSut()
        dateProvider.driftTimeForEveryRead = true
        dateProvider.driftTimeInterval = 1

        // -- Act --
        let videos = try sut.createVideoWith(
            beginning: Date(timeIntervalSinceReferenceDate: 0),
            end: Date(timeIntervalSinceReferenceDate: 10)
        )

        // -- Assert --
        XCTAssertNil(videos.first)
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

    // This test case with zero size is not particularly handled, but used
    // to lock down the expected behaviour.
    func testCreateVideoSettings_zeroSize_shouldReturnFullSettings() throws {
        // -- Arrange --
        let sut = getSut()

        // -- Act --
        let settings = sut.createVideoSettings(width: 0, height: 0)

        // -- Assert --
        XCTAssertEqual(settings.count, 5)
        XCTAssertEqual(settings[AVVideoCodecKey] as? AVVideoCodecType, AVVideoCodecType.h264)
        XCTAssertEqual(settings[AVVideoWidthKey] as? CGFloat, 0)
        XCTAssertEqual(settings[AVVideoHeightKey] as? CGFloat, 0)
        
        let compressionProperties = try XCTUnwrap(settings[AVVideoCompressionPropertiesKey] as? [String: Any], "Compression properties not found")

        XCTAssertEqual(compressionProperties.count, 4)
        XCTAssertEqual(compressionProperties[AVVideoAverageBitRateKey] as? Int, sut.bitRate)
        XCTAssertEqual(compressionProperties[AVVideoProfileLevelKey] as? String, AVVideoProfileLevelH264MainAutoLevel)
        XCTAssertEqual(compressionProperties[AVVideoAllowFrameReorderingKey] as? Bool, false)
        XCTAssertEqual(compressionProperties[AVVideoMaxKeyFrameIntervalKey] as? Int, sut.frameRate)
        
        let colorProperties = try XCTUnwrap(settings[AVVideoColorPropertiesKey] as? [String: Any], "Color properties not found")

        XCTAssertEqual(colorProperties.count, 3)
        XCTAssertEqual(colorProperties[AVVideoColorPrimariesKey] as? String, AVVideoColorPrimaries_ITU_R_709_2)
        XCTAssertEqual(colorProperties[AVVideoTransferFunctionKey] as? String, AVVideoTransferFunction_ITU_R_709_2)
        XCTAssertEqual(colorProperties[AVVideoYCbCrMatrixKey] as? String, AVVideoYCbCrMatrix_ITU_R_709_2)
    }

    func testCreateVideoSettings_anySize_shouldReturnFullSettings() throws {
        // -- Arrange --
        let sut = getSut()

        // -- Act --
        let settings = sut.createVideoSettings(width: 100, height: 100)

        // -- Assert --
        XCTAssertEqual(settings.count, 5)
        XCTAssertEqual(settings[AVVideoCodecKey] as? AVVideoCodecType, AVVideoCodecType.h264)
        XCTAssertEqual(settings[AVVideoWidthKey] as? CGFloat, 100)
        XCTAssertEqual(settings[AVVideoHeightKey] as? CGFloat, 100)
        
        let compressionProperties = try XCTUnwrap(settings[AVVideoCompressionPropertiesKey] as? [String: Any], "Compression properties not found")

        XCTAssertEqual(compressionProperties.count, 4)
        XCTAssertEqual(compressionProperties[AVVideoAverageBitRateKey] as? Int, sut.bitRate)
        XCTAssertEqual(compressionProperties[AVVideoProfileLevelKey] as? String, AVVideoProfileLevelH264MainAutoLevel)
        XCTAssertEqual(compressionProperties[AVVideoAllowFrameReorderingKey] as? Bool, false)
        XCTAssertEqual(compressionProperties[AVVideoMaxKeyFrameIntervalKey] as? Int, sut.frameRate)
        
        let colorProperties = try XCTUnwrap(settings[AVVideoColorPropertiesKey] as? [String: Any], "Color properties not found")

        XCTAssertEqual(colorProperties.count, 3)
        XCTAssertEqual(colorProperties[AVVideoColorPrimariesKey] as? String, AVVideoColorPrimaries_ITU_R_709_2)
        XCTAssertEqual(colorProperties[AVVideoTransferFunctionKey] as? String, AVVideoTransferFunction_ITU_R_709_2)
        XCTAssertEqual(colorProperties[AVVideoYCbCrMatrixKey] as? String, AVVideoYCbCrMatrix_ITU_R_709_2)
    }
}
#endif
