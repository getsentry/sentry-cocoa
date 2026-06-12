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
        var trackedInputs: [AVAssetWriterInput] = []

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
            return trackedInputs
        }
        
        override func add(_ input: AVAssetWriterInput) {
            trackedInputs.append(input)
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
        var markAsFinishedInvocations = Invocations<Void>()

        override var isReadyForMoreMediaData: Bool {
            return isReadyForMoreMediaDataOverride
        }

        override func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
            requestMediaDataWhenReadyCalled = true
            requestMediaDataWhenReadyQueue = queue
            requestMediaDataWhenReadyBlock = block
        }

        override func markAsFinished() {
            markAsFinishedInvocations.record(Void())
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

        init() throws {
            // Create test frames
            let testImagePath = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")

            videoFrames = [
                SentryReplayFrame(imagePath: testImagePath.path, time: Date(timeIntervalSinceReferenceDate: 0), screenName: "Screen1"),
                SentryReplayFrame(imagePath: testImagePath.path, time: Date(timeIntervalSinceReferenceDate: 1), screenName: "Screen2"),
                SentryReplayFrame(imagePath: testImagePath.path, time: Date(timeIntervalSinceReferenceDate: 2), screenName: "Screen3")
            ]

            currentPixelBuffer = TestSentryPixelBuffer()
            outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_video.mp4")
            videoWriter = try XCTUnwrap(TestAVAssetWriter(url: outputFileURL, fileType: .mp4))

            try createTestImage()
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
        func createTestImage() throws -> String {
            let testImage = createTestUIImage()
            let testImagePath = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")
            try testImage.pngData()?.write(to: testImagePath)
            return testImagePath.path
        }

        func cleanTestImagePath() throws {
            let testImagePath = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")
            if FileManager.default.fileExists(atPath: testImagePath.path) {
                try FileManager.default.removeItem(at: testImagePath)
            }
        }
    }

    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Clean up test files
        if FileManager.default.fileExists(atPath: fixture.outputFileURL.path) {
            try FileManager.default.removeItem(at: fixture.outputFileURL)
        }
        try fixture.cleanTestImagePath()
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

    func testProcessFrames_WhenInputIsReady_ShouldProcessAvailableFrames() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        videoWriterInput.isReadyForMoreMediaDataOverride = true

        sut.processFrames(videoWriterInput: videoWriterInput) { _ in }

        XCTAssertEqual(fixture.currentPixelBuffer.appendInvocations.count, 3)
        XCTAssertEqual(sut.frameIndex, 3)
        XCTAssertEqual(sut.usedFrames.count, 3)
    }

    func testProcessFrames_WhenFramesHaveGap_ShouldHoldPreviousFrame() {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)

        let frames = [
            SentryReplayFrame(
                imagePath: fixture.videoFrames[0].imagePath,
                time: Date(timeIntervalSinceReferenceDate: 0),
                screenName: "A"
            ),
            SentryReplayFrame(
                imagePath: fixture.videoFrames[0].imagePath,
                time: Date(timeIntervalSinceReferenceDate: 3),
                screenName: "B"
            )
        ]
        let sut = SentryVideoFrameProcessor(
            videoFrames: frames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: fixture.initialImageSize,
            videoEnd: Date(timeIntervalSinceReferenceDate: 5)
        )

        sut.processFrames(videoWriterInput: videoWriterInput) { _ in }

        XCTAssertEqual(fixture.currentPixelBuffer.appendInvocations.count, 5)
        let presentationTimes = fixture.currentPixelBuffer.appendInvocations.invocations.map { $0.presentationTime.seconds }
        XCTAssertEqual(presentationTimes, [0, 1, 2, 3, 4])
        XCTAssertEqual(sut.usedFrames.compactMap(\.screenName), ["A", "A", "A", "B", "B"])
    }

    func testProcessFrames_WhenFramesHaveFractionalGap_ShouldNotOverExpandDuration() {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)

        let frames = [
            SentryReplayFrame(
                imagePath: fixture.videoFrames[0].imagePath,
                time: Date(timeIntervalSinceReferenceDate: 0),
                screenName: "A"
            ),
            SentryReplayFrame(
                imagePath: fixture.videoFrames[0].imagePath,
                time: Date(timeIntervalSinceReferenceDate: 2.4),
                screenName: "B"
            )
        ]
        let sut = SentryVideoFrameProcessor(
            videoFrames: frames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: fixture.initialImageSize,
            videoEnd: Date(timeIntervalSinceReferenceDate: 2.4)
        )

        sut.processFrames(videoWriterInput: videoWriterInput) { _ in }

        XCTAssertEqual(fixture.currentPixelBuffer.appendInvocations.count, 3)
        let presentationTimes = fixture.currentPixelBuffer.appendInvocations.invocations.map { $0.presentationTime.seconds }
        XCTAssertEqual(presentationTimes, [0, 1, 2])
        XCTAssertEqual(sut.usedFrames.compactMap(\.screenName), ["A", "A", "B"])
    }

    func testProcessFrames_WhenVideoEndHasFractionalGap_ShouldNotCompressDuration() {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)

        let frames = [
            SentryReplayFrame(
                imagePath: fixture.videoFrames[0].imagePath,
                time: Date(timeIntervalSinceReferenceDate: 0),
                screenName: "A"
            )
        ]
        let sut = SentryVideoFrameProcessor(
            videoFrames: frames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: fixture.initialImageSize,
            videoEnd: Date(timeIntervalSinceReferenceDate: 2.4)
        )

        sut.processFrames(videoWriterInput: videoWriterInput) { _ in }

        XCTAssertEqual(fixture.currentPixelBuffer.appendInvocations.count, 3)
        let presentationTimes = fixture.currentPixelBuffer.appendInvocations.invocations.map { $0.presentationTime.seconds }
        XCTAssertEqual(presentationTimes, [0, 1, 2])
        XCTAssertEqual(sut.usedFrames.compactMap(\.screenName), ["A", "A", "A"])
    }

    func testProcessFrames_WhenVideoWriterNotWriting_ShouldCancelWriting() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        fixture.videoWriter.statusOverride = .failed
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.cancelWritingCalled)
        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
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
        fixture.videoWriter.add(videoWriterInput)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Process all frames
        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.finishWritingCalled)
        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
        XCTAssertEqual(completionInvocations.count, 1)
    }

    func testProcessFrames_WhenImageSizeChanges_ShouldFinishVideo() {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
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
        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
        XCTAssertEqual(completionInvocations.count, 1)
    }

    func testProcessFrames_WhenPixelBufferAppendFails_ShouldCancelWriting() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        fixture.currentPixelBuffer.appendShouldReturn = false
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Process all frames
        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.cancelWritingCalled)
        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
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

    func testProcessFrames_WhenInitialImageCannotBeLoaded_ShouldSkipFrame() {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Create frames with non-existent image paths
        let nonExistentFrames = [
            SentryReplayFrame(imagePath: "/another/non/existent/path.png", time: Date(timeIntervalSinceReferenceDate: 1), screenName: "Screen2")
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

        XCTAssertEqual(sutWithNonExistentFrames.frameIndex, 1)
        XCTAssertEqual(sutWithNonExistentFrames.usedFrames.count, 0)
        XCTAssertEqual(fixture.currentPixelBuffer.appendInvocations.count, 0)
    }

    func testProcessFrames_WhenTrailingImageCannotBeLoaded_ShouldHoldPreviousFrame() throws {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)

        let frames = [
            SentryReplayFrame(
                imagePath: try fixture.createTestImage(),
                time: Date(timeIntervalSinceReferenceDate: 0),
                screenName: "A"
            ),
            SentryReplayFrame(
                imagePath: "/non/existent/path.png",
                time: Date(timeIntervalSinceReferenceDate: 3),
                screenName: "Missing"
            )
        ]
        let sut = SentryVideoFrameProcessor(
            videoFrames: frames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: fixture.initialImageSize
        )

        sut.processFrames(videoWriterInput: videoWriterInput) { _ in }

        XCTAssertEqual(fixture.currentPixelBuffer.appendInvocations.count, 3)
        let presentationTimes = fixture.currentPixelBuffer.appendInvocations.invocations.map { $0.presentationTime.seconds }
        XCTAssertEqual(presentationTimes, [0, 1, 2])
        XCTAssertEqual(sut.usedFrames.compactMap(\.screenName), ["A", "A", "A"])
    }

    // MARK: - Finish Video Tests

    func testFinishVideo_WhenWriterCompleted_ShouldReturnVideoInfo() throws {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        fixture.videoWriter.statusOverride = .completed
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Create a test video file
        let testData = Data("test video data".utf8)
        try testData.write(to: fixture.outputFileURL)

        // Add some used frames
        sut.usedFrames = fixture.videoFrames

        sut.finishVideo(frameIndex: 3, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
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

    func testFinishVideo_WhenWriterCompletedWithoutUsedFrames_ShouldReturnNilVideoInfo() throws {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        fixture.videoWriter.statusOverride = .completed
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        try Data("empty video data".utf8).write(to: fixture.outputFileURL)

        sut.finishVideo(frameIndex: 1) { result in
            completionInvocations.record(result)
        }

        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
        XCTAssertEqual(completionInvocations.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.outputFileURL.path))

        let result = completionInvocations.invocations.first
        XCTAssertNotNil(result)

        switch result {
        case .success(let videoResult):
            XCTAssertEqual(videoResult.finalFrameIndex, 1)
            XCTAssertNil(videoResult.info)
        default:
            XCTFail("Expected success result with nil info")
        }
    }

    func testFinishVideo_WhenWriterCancelled_ShouldReturnNilVideoInfo() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        fixture.videoWriter.statusOverride = .cancelled
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        sut.finishVideo(frameIndex: 2, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
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
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        fixture.videoWriter.statusOverride = .failed
        fixture.videoWriter.errorOverride = SentryOnDemandReplayError.errorRenderingVideo
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        sut.finishVideo(frameIndex: 1, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
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

    func testFinishVideo_WhenSelfIsDeallocated_ShouldReturnNilVideoInfo() throws {
        let delayedVideoWriter = try XCTUnwrap(DelayedTestAVAssetWriter(url: fixture.outputFileURL, fileType: .mp4))
        delayedVideoWriter.statusOverride = .completed
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        delayedVideoWriter.add(videoWriterInput)
        
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
        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
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

    func testFinishVideo_WhenOutputFileDoesNotExist_ShouldReturnError() throws {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        fixture.videoWriter.statusOverride = .completed
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Ensure the output file doesn't exist
        if FileManager.default.fileExists(atPath: fixture.outputFileURL.path) {
            try FileManager.default.removeItem(at: fixture.outputFileURL)
        }

        // Add some used frames
        sut.usedFrames = fixture.videoFrames

        sut.finishVideo(frameIndex: 3, onCompletion: { result in
            completionInvocations.record(result)
        })

        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
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

    func testGetVideoInfo_WithMoreThanOneFPS_ShouldUseFractionalDuration() throws {
        let sut = SentryVideoFrameProcessor(
            videoFrames: fixture.videoFrames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: 2,
            initialFrameIndex: fixture.initialFrameIndex,
            initialImageSize: fixture.initialImageSize
        )
        let testData = Data("test video data".utf8)
        try testData.write(to: fixture.outputFileURL)

        let videoInfo = try sut.getVideoInfo(
            from: fixture.outputFileURL,
            usedFrames: fixture.videoFrames,
            videoWidth: 200,
            videoHeight: 100
        )

        XCTAssertEqual(videoInfo.duration, 1.5)
        XCTAssertEqual(videoInfo.end, Date(timeIntervalSinceReferenceDate: 1.5))
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

    func testGetVideoInfo_WithEmptyUsedFrames_ShouldThrowError() throws {
        let sut = fixture.getSut()

        // Create a test video file
        let testData = Data("test video data".utf8)
        try testData.write(to: fixture.outputFileURL)

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
        fixture.videoWriter.add(videoWriterInput)
        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.finishWritingCalled)
        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
        XCTAssertEqual(completionInvocations.count, 1)
        XCTAssertEqual(sut.frameIndex, 0)
    }

    func testProcessFrames_WithLargeFrameIndex_ShouldFinishImmediately() {
        let sut = fixture.getSut()
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        fixture.videoWriter.add(videoWriterInput)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        // Set frame index beyond available frames
        sut.frameIndex = 10

        sut.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertTrue(fixture.videoWriter.finishWritingCalled)
        XCTAssertEqual(videoWriterInput.markAsFinishedInvocations.count, 1)
        XCTAssertEqual(completionInvocations.count, 1)
        XCTAssertEqual(sut.frameIndex, 10)
    }

    func testProcessFrames_WithMixedValidAndInvalidFrames_ShouldProcessValidFrames() throws {
        let videoWriterInput = TestAVAssetWriterInput(mediaType: .video, outputSettings: nil)
        let completionInvocations = Invocations<Result<SentryRenderVideoResult, any Error>>()

        let mixedFrames = [
            SentryReplayFrame(imagePath: try fixture.createTestImage(), time: Date(timeIntervalSinceReferenceDate: 0), screenName: "Valid1"),
            SentryReplayFrame(imagePath: "/non/existent/path.png", time: Date(timeIntervalSinceReferenceDate: 1), screenName: "Invalid"),
            SentryReplayFrame(imagePath: try fixture.createTestImage(), time: Date(timeIntervalSinceReferenceDate: 2), screenName: "Valid2")
        ]

        let sutWithMixedFrames = SentryVideoFrameProcessor(
            videoFrames: mixedFrames,
            videoWriter: fixture.videoWriter,
            currentPixelBuffer: fixture.currentPixelBuffer,
            outputFileURL: fixture.outputFileURL,
            videoHeight: fixture.videoHeight,
            videoWidth: fixture.videoWidth,
            frameRate: fixture.frameRate,
            initialFrameIndex: 0,
            initialImageSize: fixture.initialImageSize
        )

        sutWithMixedFrames.processFrames(videoWriterInput: videoWriterInput) { completionInvocations.record($0) }

        XCTAssertEqual(sutWithMixedFrames.frameIndex, 3)
        // 3 used frames: Valid1 at t=0, gap-fill (holding Valid1) at t=1, Valid2 at t=2
        XCTAssertEqual(sutWithMixedFrames.usedFrames.count, 3)
        XCTAssertEqual(sutWithMixedFrames.usedFrames.compactMap(\.screenName), ["Valid1", "Valid1", "Valid2"])
    }
}

#endif // os(iOS) || os(tvOS)
