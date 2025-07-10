import AVFoundation
import CoreGraphics
import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentryVideoFrameProcessorTests: XCTestCase {

    private class TestSentryPixelBuffer: SentryAppendablePixelBuffer {
        var appendInvocations = Invocations<(image: UIImage, presentationTime: CMTime)>()
        var appendShouldReturn = true
        var appendShouldThrow = false

        func append(image: UIImage, presentationTime: CMTime) -> Bool {
            appendInvocations.record((image: image, presentationTime: presentationTime))
            if appendShouldThrow {
                return false
            }
            return appendShouldReturn
        }
    }

    private class TestAVAssetWriter: AVAssetWriter {
        var statusOverride: AVAssetWriter.Status = .writing
        var errorOverride: Error?
        var cancelWritingCalled = false
        var finishWritingCalled = false
        var markAsFinishedCalled = false

        override var status: AVAssetWriter.Status {
            return statusOverride
        }

        override var error: Error? {
            return errorOverride
        }

        override func cancelWriting() {
            cancelWritingCalled = true
        }

        override func finishWriting(completionHandler: @escaping () -> Void) {
            finishWritingCalled = true
            completionHandler()
        }

        override var inputs: [AVAssetWriterInput] {
            return []
        }
    }

    // Create a test AVAssetWriter that doesn't execute completion immediately
    private class DelayedTestAVAssetWriter: TestAVAssetWriter {
        var completionHandler: (() -> Void)?
        var shouldExecuteCompletionImmediately = false
        
        override func finishWriting(completionHandler: @escaping () -> Void) {
            finishWritingCalled = true
            if shouldExecuteCompletionImmediately {
                completionHandler()
            } else {
                self.completionHandler = completionHandler
            }
        }
        
        func executeCompletion() {
            completionHandler?()
            completionHandler = nil
        }
    }

    private class TestAVAssetWriterInput: AVAssetWriterInput {
        var isReadyForMoreMediaDataOverride = true
        var requestMediaDataWhenReadyCalled = false
        var requestMediaDataWhenReadyQueue: DispatchQueue?
        var requestMediaDataWhenReadyBlock: (() -> Void)?

        override var isReadyForMoreMediaData: Bool {
            return isReadyForMoreMediaDataOverride
        }

        override func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
            requestMediaDataWhenReadyCalled = true
            requestMediaDataWhenReadyQueue = queue
            requestMediaDataWhenReadyBlock = block
        }

        override func markAsFinished() {
            // No-op for testing
        }
    }

    private class Fixture {
        let videoFrames: [SentryReplayFrame]
        let videoWriter: TestAVAssetWriter
        let currentPixelBuffer: TestSentryPixelBuffer
        let outputFileURL: URL
        let videoHeight: CGFloat = 100
        let videoWidth: CGFloat = 200
        let frameRate: Int = 1
        let initialFrameIndex: Int = 0
        let initialImageSize: CGSize = CGSize(width: 200, height: 100)

        init() {
            // Create test frames
            let testImagePath = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")

            videoFrames = [
                SentryReplayFrame(imagePath: testImagePath.path, time: Date(timeIntervalSinceReferenceDate: 0), screenName: "Screen1"),
                SentryReplayFrame(imagePath: testImagePath.path, time: Date(timeIntervalSinceReferenceDate: 1), screenName: "Screen2"),
                SentryReplayFrame(imagePath: testImagePath.path, time: Date(timeIntervalSinceReferenceDate: 2), screenName: "Screen3")
            ]

            currentPixelBuffer = TestSentryPixelBuffer()
            outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_video.mp4")
            videoWriter = try! TestAVAssetWriter(url: outputFileURL, fileType: .mp4)

            createTestImage()
        }

        func getSut() -> SentryVideoFrameProcessor {
            return SentryVideoFrameProcessor(
                videoFrames: videoFrames,
                videoWriter: videoWriter,
                currentPixelBuffer: currentPixelBuffer,
                outputFileURL: outputFileURL,
                videoHeight: videoHeight,
                videoWidth: videoWidth,
                frameRate: frameRate,
                initialFrameIndex: initialFrameIndex,
                initialImageSize: initialImageSize
            )
        }

        func createTestUIImage() -> UIImage {
            let size = CGSize(width: 200, height: 100)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // avoid scaling

            let renderer = UIGraphicsImageRenderer(size: size, format: format)

            let image = renderer.image { _ in
            }

            return image
        }

        @discardableResult
        func createTestImage() -> String {
            let testImage = createTestUIImage()
            let testImagePath = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")
            try? testImage.pngData()?.write(to: testImagePath)
            return testImagePath.path
        }

        func cleanTestImagePath() {
            let testImagePath = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")
            try? FileManager.default.removeItem(atPath: testImagePath.path)
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        // Clean up test files
        try? FileManager.default.removeItem(at: fixture.outputFileURL)
        fixture.cleanTestImagePath()
    }

    // MARK: - Initialization Tests

    func testInit_WithValidParameters_ShouldInitializeCorrectly() {
        let sut = fixture.getSut()

        XCTAssertEqual(sut.videoFrames.count, 3)
        XCTAssertEqual(sut.videoHeight, 100)
        XCTAssertEqual(sut.videoWidth, 200)
        XCTAssertEqual(sut.frameRate, 1)
        XCTAssertEqual(sut.frameIndex, 0)
        XCTAssertEqual(sut.lastImageSize, CGSize(width: 200, height: 100))
        XCTAssertEqual(sut.usedFrames.count, 0)
    }

    // MARK: - Process Frames Tests

    func testProcessFrames_WhenInputIsReady_ShouldProcessAvailableFrame() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        videoWriterInput.isReadyForMoreMediaDataOverride = true

        sut.processFrames(videoWriterInput: videoWriterInput) { _ in }

        XCTAssertEqual(fixture.currentPixelBuffer.appendInvocations.count, 1)
        XCTAssertEqual(sut.frameIndex, 1)
        XCTAssertEqual(sut.usedFrames.count, 1)
    }

    func testProcessFrames_WhenVideoWriterNotWriting_ShouldCancelWriting() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.statusOverride = .failed
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.cancelWritingCalled)
        XCTAssertEqual(completionInvocations.count, 1)

        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)

        switch result {
        case .failure(let error):
            XCTAssertTrue(error is SentryOnDemandReplayError)
        default:
            XCTFail("Expected failure result")
        }
    }

    func testProcessFrames_WhenNoMoreFrames_ShouldFinishVideo() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Process all frames
        for _ in 0..<sut.videoFrames.count {
            sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }
        }

        // Process again - should finish video
        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.finishWritingCalled)
        XCTAssertEqual(completionInvocations.count, 1)
    }

    func testProcessFrames_WhenImageSizeChanges_ShouldFinishVideo() {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()
        let sutWithDifferentSize = SentryVideoFrameProcessor(
            videoFrames: fixture.videoFrames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: CGSize(width: 300, height: 150) // Any other size works
        )

        sutWithDifferentSize.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.finishWritingCalled)
        XCTAssertEqual(completionInvocations.count, 1)
    }

    func testProcessFrames_WhenPixelBufferAppendFails_ShouldCancelWriting() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.currentPixelBuffer.appendShouldReturn = false
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Process all frames
        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.cancelWritingCalled)
        XCTAssertEqual(completionInvocations.count, 1)

        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)

        switch result {
        case .failure(let error):
            XCTAssertTrue(error is SentryOnDemandReplayError)
        default:
            XCTFail("Expected failure result")
        }
    }

    func testProcessFrames_WhenImageCannotBeLoaded_ShouldSkipFrame() {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Create frames with non-existent image paths
        let nonExistentFrames = [
            SentryReplayFrame(imagePath: "/another/non/existent/path.png", time: Date(), screenName: "Screen2")
        ]

        let sutWithNonExistentFrames = SentryVideoFrameProcessor(
            videoFrames: nonExistentFrames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: fixture.initialImageSize
        )

        sutWithNonExistentFrames.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        // Should still increment frame index even if image can't be loaded
        XCTAssertEqual(sutWithNonExistentFrames.frameIndex, 1)
        XCTAssertEqual(sutWithNonExistentFrames.usedFrames.count, 0)
    }

    // MARK: - Finish Video Tests

    func testFinishVideo_WhenWriterCompleted_ShouldReturnVideoInfo() {
        let sut = fixture.getSut()
        fixture.videoWriter.statusOverride = .completed
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Create a test video file
        let testData = Data("test video data".utf8)
        try? testData.write(to: fixture.outputFileURL)

        // Add some used frames
        sut.usedFrames = fixture.videoFrames

        sut.finishVideo(frameIndex: 3, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(completionInvocations.count, 1)

        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)

        switch result {
        case .success(let videoResult):
            XCTAssertNotNil(videoResult)
            XCTAssertEqual(videoResult.finalFrameIndex, 3)
            XCTAssertNotNil(videoResult.info)
            if let info = videoResult.info {
                XCTAssertEqual(info.frameCount, 3)
                XCTAssertEqual(info.frameRate, 1)
                XCTAssertEqual(info.width, 200)
                XCTAssertEqual(info.height, 100)
            }
        default:
            XCTFail("Expected success result")
        }
    }

    func testFinishVideo_WhenWriterCancelled_ShouldReturnNilVideoInfo() {
        let sut = fixture.getSut()
        fixture.videoWriter.statusOverride = .cancelled
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        sut.finishVideo(frameIndex: 2, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(completionInvocations.count, 1)

        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)

        switch result {
        case .success(let videoResult):
            XCTAssertNotNil(videoResult)
            XCTAssertEqual(videoResult.finalFrameIndex, 2)
            XCTAssertNil(videoResult.info)
        default:
            XCTFail("Expected success result with nil info")
        }
    }

    func testFinishVideo_WhenWriterFailed_ShouldReturnError() {
        let sut = fixture.getSut()
        fixture.videoWriter.statusOverride = .failed
        fixture.videoWriter.errorOverride = SentryOnDemandReplayError.errorRenderingVideo
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        sut.finishVideo(frameIndex: 1, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(completionInvocations.count, 1)

        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)

        switch result {
        case .failure(let error):
            XCTAssertTrue(error is SentryOnDemandReplayError)
        default:
            XCTFail("Expected failure result")
        }
    }

    func testFinishVideo_WhenSelfIsDeallocated_ShouldReturnNilVideoInfo() {
        let delayedVideoWriter = try! DelayedTestAVAssetWriter(url: fixture.outputFileURL, fileType: .mp4)
        delayedVideoWriter.statusOverride = .completed
        
        // Create a weak reference to track deallocation
        weak var weakSut: SentryVideoFrameProcessor?
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()
        
        // Create the processor in a scope that will be deallocated
        autoreleasepool {
            let sut = SentryVideoFrameProcessor(
                videoFrames: fixture.videoFrames,
                videoWriter: delayedVideoWriter,
                currentPixelBuffer: fixture.currentPixelBuffer,
                outputFileURL: fixture.outputFileURL,
                videoHeight: fixture.videoHeight,
                videoWidth: fixture.videoWidth,
                frameRate: fixture.frameRate,
                initialFrameIndex: 0,
                initialImageSize: fixture.initialImageSize
            )
            weakSut = sut
            
            // Start finishVideo but don't wait for completion
            sut.finishVideo(frameIndex: 5, onCompletion: { result in
                completionInvocations.record(result)
            })
            
            // The sut should be deallocated when this scope ends
        }
        
        // Verify the instance was deallocated
        XCTAssertNil(weakSut, "SUT should be deallocated")
        
        // Now execute the completion handler after deallocation
        delayedVideoWriter.executeCompletion()
        
        // Verify the completion was called with nil video info
        XCTAssertEqual(completionInvocations.count, 1)
        
        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)
        
        switch result {
        case .success(let videoResult):
            XCTAssertNotNil(videoResult)
            XCTAssertEqual(videoResult.finalFrameIndex, 5)
            XCTAssertNil(videoResult.info, "Video info should be nil when self is deallocated")
        default:
            XCTFail("Expected success result with nil info")
        }
    }

    func testFinishVideo_WhenOutputFileDoesNotExist_ShouldReturnError() {
        let sut = fixture.getSut()
        fixture.videoWriter.statusOverride = .completed
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Ensure the output file doesn't exist
        try? FileManager.default.removeItem(at: fixture.outputFileURL)

        // Add some used frames
        sut.usedFrames = fixture.videoFrames

        sut.finishVideo(frameIndex: 3, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(completionInvocations.count, 1)

        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)

        switch result {
        case .failure(let error):
            // The error should be related to file system operations
            XCTAssertTrue(error is SentryOnDemandReplayError || error.localizedDescription.contains("file"))
        default:
            XCTFail("Expected failure result when output file doesn't exist")
        }
    }

    // MARK: - Get Video Info Tests

    func testGetVideoInfo_WithValidFile_ShouldReturnVideoInfo() throws {
        let sut = fixture.getSut()

        // Create a test video file
        let testData = Data("test video data".utf8)
        try testData.write(to: fixture.outputFileURL)

        // Add used frames
        sut.usedFrames = fixture.videoFrames

        let videoInfo = try sut.getVideoInfo(
            from: fixture.outputFileURL,
            usedFrames: fixture.videoFrames,
            videoWidth: 200,
            videoHeight: 100
        )

        XCTAssertEqual(videoInfo.path, fixture.outputFileURL)
        XCTAssertEqual(videoInfo.width, 200)
        XCTAssertEqual(videoInfo.height, 100)
        XCTAssertEqual(videoInfo.frameCount, 3)
        XCTAssertEqual(videoInfo.frameRate, 1)
        XCTAssertEqual(videoInfo.fileSize, testData.count)
        XCTAssertEqual(videoInfo.screens, ["Screen1", "Screen2", "Screen3"])
    }

    func testGetVideoInfo_WithNonExistentFile_ShouldThrowError() {
        let sut = fixture.getSut()

        XCTAssertThrowsError(try sut.getVideoInfo(
            from: URL(fileURLWithPath: "/non/existent/file.mp4"),
            usedFrames: fixture.videoFrames,
            videoWidth: 200,
            videoHeight: 100
        ))
    }

    func testGetVideoInfo_WithEmptyUsedFrames_ShouldThrowError() {
        let sut = fixture.getSut()

        // Create a test video file
        let testData = Data("test video data".utf8)
        try? testData.write(to: fixture.outputFileURL)

        XCTAssertThrowsError(try sut.getVideoInfo(
            from: fixture.outputFileURL,
            usedFrames: [],
            videoWidth: 200,
            videoHeight: 100
        )) { error in
            XCTAssertTrue(error is SentryOnDemandReplayError)
        }
    }

    // MARK: - Edge Cases

    func testProcessFrames_WithEmptyFramesArray_ShouldFinishImmediately() {
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()
        let sut = SentryVideoFrameProcessor(
            videoFrames: [],
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: fixture.initialImageSize
        )

        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.finishWritingCalled)
        XCTAssertEqual(completionInvocations.count, 1)
        XCTAssertEqual(sut.frameIndex, 0)
    }

    func testProcessFrames_WithLargeFrameIndex_ShouldFinishImmediately() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Set frame index beyond available frames
        sut.frameIndex = 10

        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.finishWritingCalled)
        XCTAssertEqual(completionInvocations.count, 1)
        XCTAssertEqual(sut.frameIndex, 10)
    }
}

#endif // os(iOS) || os(tvOS)
