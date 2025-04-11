// swiftlint:disable file_length
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import AVFoundation
import CoreGraphics
import Foundation
import UIKit

// swiftlint:disable type_body_length
@objcMembers
class SentryOnDemandReplay: NSObject, SentryReplayVideoMaker {
        
    private let _outputPath: String
    private var _totalFrames = 0
    private let dateProvider: SentryCurrentDateProvider
    private let processingQueue: SentryDispatchQueueWrapper
    private let assetWorkerQueue: SentryDispatchQueueWrapper
    private var _frames = [SentryReplayFrame]()

    #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
    //This is exposed only for tests, no need to make it thread safe.
    var frames: [SentryReplayFrame] {
        get { _frames }
        set { _frames = newValue }
    }
    #endif // SENTRY_TEST || SENTRY_TEST_CI || DEBUG
    var videoScale: Float = 1
    var bitRate = 20_000
    var frameRate = 1
    var cacheMaxSize = UInt.max
        
    init(
        outputPath: String,
        processingQueue: SentryDispatchQueueWrapper,
        assetWorkerQueue: SentryDispatchQueueWrapper,
        dateProvider: SentryCurrentDateProvider
    ) {
        assert(processingQueue != assetWorkerQueue, "Processing and asset worker queue must not be the same.")
        self._outputPath = outputPath
        self.dateProvider = dateProvider
        self.processingQueue = processingQueue
        self.assetWorkerQueue = assetWorkerQueue
    }
        
    convenience init(
        withContentFrom outputPath: String,
        processingQueue: SentryDispatchQueueWrapper,
        assetWorkerQueue: SentryDispatchQueueWrapper,
        dateProvider: SentryCurrentDateProvider
    ) {
        self.init(
            outputPath: outputPath,
            processingQueue: processingQueue,
            assetWorkerQueue: assetWorkerQueue,
            dateProvider: dateProvider
        )
        loadFrames(fromPath: outputPath)
    }

    /// Loads the frames from the given path.
    ///
    /// - Parameter path: The path to the directory containing the frames.
    private func loadFrames(fromPath path: String) {
        SentryLog.debug("[Session Replay] Loading frames from path: \(path)")
        do {
            let content = try FileManager.default.contentsOfDirectory(atPath: path)
            _frames = content.compactMap { frameFilePath -> SentryReplayFrame? in
                guard frameFilePath.hasSuffix(".png") else { return nil }
                guard let time = Double(frameFilePath.dropLast(4)) else { return nil }
                let timestamp = Date(timeIntervalSinceReferenceDate: time)
                return SentryReplayFrame(imagePath: "\(path)/\(frameFilePath)", time: timestamp, screenName: nil)
            }.sorted { $0.time < $1.time }
            SentryLog.debug("[Session Replay] Loaded \(content.count) files into \(_frames.count) frames from path: \(path)")
        } catch {
            SentryLog.error("[Session Replay] Could not list frames from replay: \(error.localizedDescription)")
        }
    }

    func addFrameAsync(image: UIImage, forScreen: String?) {
        // Dispatch the frame addition to a background queue to avoid blocking the main queue.
        // This must be on the processing queue to avoid deadlocks.
        processingQueue.dispatchAsync {
            self.addFrame(image: image, forScreen: forScreen)
        }
    }
    
    private func addFrame(image: UIImage, forScreen: String?) {
        guard let data = rescaleImage(image)?.pngData() else { return }
        
        let date = dateProvider.date()
        let imagePath = (_outputPath as NSString).appendingPathComponent("\(date.timeIntervalSinceReferenceDate).png")
        do {
            try data.write(to: URL(fileURLWithPath: imagePath))
        } catch {
            SentryLog.error("[Session Replay] Could not save replay frame. Error: \(error)")
            return
        }
        _frames.append(SentryReplayFrame(imagePath: imagePath, time: date, screenName: forScreen))

        // Remove the oldest frames if the cache size exceeds the maximum size.
        while _frames.count > cacheMaxSize {
            let first = _frames.removeFirst()
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
        }
        _totalFrames += 1
    }
    
    private func rescaleImage(_ originalImage: UIImage) -> UIImage? {
        guard originalImage.scale > 1 else { return originalImage }
        
        UIGraphicsBeginImageContextWithOptions(originalImage.size, false, 1)
        defer { UIGraphicsEndImageContext() }
        
        originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func releaseFramesUntil(_ date: Date) {
        processingQueue.dispatchAsync {
            SentryLog.debug("[Session Replay] Releasing frames until date: \(date), current queue: \(self.processingQueue.queue.label)")
            while let first = self._frames.first, first.time < date {
                self._frames.removeFirst()
                let fileUrl = URL(fileURLWithPath: first.imagePath)
                do {
                    try FileManager.default.removeItem(at: fileUrl)
                    SentryLog.debug("[Session Replay] Removed frame at url: \(fileUrl.path)")
                } catch {
                    SentryLog.error("[Session Replay] Failed to remove frame at: \(fileUrl.path), reason: \(error.localizedDescription), ignoring error")
                }
            }
        }
    }
        
    var oldestFrameDate: Date? {
        return _frames.first?.time
    }

    func createVideoAsyncWith(beginning: Date, end: Date, completion: @escaping ([SentryVideoInfo]?, Error?) -> Void) {
        // Note: In Swift it is best practice to use `Result<Value, Error>` instead of `(Value?, Error?)`
        //       Due to interoperability with Objective-C and @objc, we can not use Result here.
        SentryLog.debug("[Session Replay] Creating video with beginning: \(beginning), end: \(end)")        

        // Dispatch the video creation to a background queue to avoid blocking the calling queue.
        processingQueue.dispatchAsync {
            SentryLog.debug("[Session Replay] Creating video with beginning: \(beginning), end: \(end), current queue: \(self.processingQueue.queue.label)")
            
            let videoFrames = self._frames.filter { $0.time >= beginning && $0.time <= end }
     
            do {
                // Use a semaphore to wait for each video segment to finish.
                let semaphore = DispatchSemaphore(value: 0)
                var currentError: Error?
                var frameIndex = 0
                var videos = [SentryVideoInfo]()
                while frameIndex < videoFrames.count {
                    let frame = videoFrames[frameIndex]
                    let outputFileURL = URL(fileURLWithPath: self._outputPath)
                        .appendingPathComponent("\(frame.time.timeIntervalSinceReferenceDate)")
                        .appendingPathExtension("mp4")
                    self.renderVideo(with: videoFrames, from: frameIndex, at: outputFileURL) { result in
                        // Do not use `processingQueue` here, since it will be blocked by the semaphore.
                        switch result {
                        case .success(let videoResult):
                            frameIndex = videoResult.finalFrameIndex
                            if let videoInfo = videoResult.info {
                                videos.append(videoInfo)
                            }
                        case .failure(let error):
                            SentryLog.error("[Session Replay] Failed to render video with error: \(error)")
                            currentError = error
                        }
                        semaphore.signal()
                    }

                    // Calling semaphore.wait will block the `processingQueue` until the video rendering completes or a timeout occurs.
                    // It is imporant that the renderVideo completion block signals the semaphore.
                    // The queue used by render video must have a higher priority than the processing queue to reduce thread inversion.
                    // Otherwise, it could lead to queue starvation and a deadlock.
                    if semaphore.wait(timeout: .now() + 2) == .timedOut {
                        SentryLog.error("[Session Replay] Timeout while waiting for video rendering to finish.")
                        currentError = SentryOnDemandReplayError.errorRenderingVideo
                        break
                    }

                    // If there was an error, throw it to exit the loop.
                    if let error = currentError {
                        throw error
                    }

                    SentryLog.debug("[Session Replay] Finished rendering video, frame count moved to: \(frameIndex)")
                }
                completion(videos, nil)
            } catch {
                SentryLog.error("[Session Replay] Failed to create video with error: \(error)")
                completion(nil, error)
            }
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private func renderVideo(with videoFrames: [SentryReplayFrame], from: Int, at outputFileURL: URL, completion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void) {
        SentryLog.debug("[Session Replay] Rendering video with \(videoFrames.count) frames, from index: \(from), to output url: \(outputFileURL)")
        guard from < videoFrames.count, let image = UIImage(contentsOfFile: videoFrames[from].imagePath) else {
            SentryLog.debug("[Session Replay] Failed to render video, reason: index out of bounds or can't read image at path: \(videoFrames[from].imagePath)")
            return completion(.success(SentryRenderVideoResult(
                info: nil,
                finalFrameIndex: from
            )))
        }
        
        let videoWidth = image.size.width * CGFloat(videoScale)
        let videoHeight = image.size.height * CGFloat(videoScale)
        let pixelSize = CGSize(width: videoWidth, height: videoHeight)

        let videoWriter: AVAssetWriter
        do {
            videoWriter = try AVAssetWriter(url: outputFileURL, fileType: .mp4)
        } catch {
            SentryLog.debug("[Session Replay] Failed to create video writer, reason: \(error)")
            return completion(.failure(error))
        }

        SentryLog.debug("[Session Replay] Creating pixel buffer based video writer input")
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: createVideoSettings(width: videoWidth, height: videoHeight))
        guard let currentPixelBuffer = SentryPixelBuffer(size: pixelSize, videoWriterInput: videoWriterInput) else {
            SentryLog.debug("[Session Replay] Failed to create pixel buffer, reason: \(SentryOnDemandReplayError.cantCreatePixelBuffer)")
            return completion(.failure(SentryOnDemandReplayError.cantCreatePixelBuffer))
        }
        videoWriter.add(videoWriterInput)

        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)

        // Append frames to the video writer input in a pull-style manner when the input is ready to receive more media data.
        //
        // Inside the callback:
        // 1. We append media data until `isReadyForMoreMediaData` becomes false
        // 2. Or until there's no more media data to process (then we mark input as finished)
        // 3. If we don't mark the input as finished, the callback will be invoked again
        //    when the input is ready for more data
        //
        // By setting the queue to the asset worker queue, we ensure that the callback is invoked on the asset worker queue.
        // This is important to avoid a deadlock, as this method is called on the processing queue.
        var lastImageSize: CGSize = image.size
        var usedFrames = [SentryReplayFrame]()
        var frameIndex = from

        // Convenience wrapper to handle the completion callback
        let deferredCompletionCallback: (Result<SentryVideoInfo?, Error>) -> Void = { result in
            switch result {
            case .success(let videoResult):
                completion(.success(SentryRenderVideoResult(
                    info: videoResult,
                    finalFrameIndex: frameIndex
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        videoWriterInput.requestMediaDataWhenReady(on: assetWorkerQueue.queue) { [weak self] in
            guard let self = self else {
                SentryLog.warning("[Session Replay] On-demand replay is deallocated, completing writing session without output video info")
                return deferredCompletionCallback(.success(nil))
            }
            guard videoWriter.status == .writing else {
                SentryLog.warning("[Session Replay] Video writer is not writing anymore, cancelling the writing session, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                videoWriter.cancelWriting()
                return completion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            }
            guard frameIndex < videoFrames.count else {
                SentryLog.debug("[Session Replay] No more frames available to process, finishing the video")
                return self.finishVideo(
                    outputFileURL: outputFileURL,
                    usedFrames: usedFrames,
                    videoHeight: Int(videoHeight),
                    videoWidth: Int(videoWidth),
                    videoWriter: videoWriter,
                    onCompletion: deferredCompletionCallback
                )
            }

            let frame = videoFrames[frameIndex]
            if let image = UIImage(contentsOfFile: frame.imagePath) {
                guard lastImageSize == image.size else {
                    SentryLog.debug("[Session Replay] Image size changed, finishing the video")
                    return self.finishVideo(
                        outputFileURL: outputFileURL,
                        usedFrames: usedFrames,
                        videoHeight: Int(videoHeight),
                        videoWidth: Int(videoWidth),
                        videoWriter: videoWriter,
                        onCompletion: deferredCompletionCallback
                    )
                }
                lastImageSize = image.size

                let presentTime = CMTime(seconds: Double(frameIndex), preferredTimescale: CMTimeScale(1 / self.frameRate))
                guard currentPixelBuffer.append(image: image, presentationTime: presentTime) == true else {
                    SentryLog.debug("[Session Replay] Failed to append image to pixel buffer, cancelling the writing session, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                    videoWriter.cancelWriting()
                    return completion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
                }
                usedFrames.append(frame)
            }
            frameIndex += 1
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    private func finishVideo(
        outputFileURL: URL,
        usedFrames: [SentryReplayFrame],
        videoHeight: Int,
        videoWidth: Int,
        videoWriter: AVAssetWriter,
        onCompletion completion: @escaping (Result<SentryVideoInfo?, Error>) -> Void
    ) {
        // Note: This method is expected to be called from the asset worker queue and *not* the processing queue.
        SentryLog.debug("[Session Replay] Finishing video with output file URL: \(outputFileURL.path)")
        videoWriter.inputs.forEach { $0.markAsFinished() }
        videoWriter.finishWriting { [weak self] in
            SentryLog.debug("[Session Replay] Finished video writing, status: \(videoWriter.status)")
            guard let strongSelf = self else {
                SentryLog.warning("[Session Replay] On-demand replay is deallocated, completing writing session without output video info")
                return completion(.success(nil))
            }

            switch videoWriter.status {
            case .writing:
                // noop
                break
            case .cancelled:
                SentryLog.debug("[Session Replay] Finish writing video was cancelled, completing with no video info")
                completion(.success(nil))
            case .completed:
                SentryLog.debug("[Session Replay] Finish writing video was completed, creating video info from file attributes")
                do {
                    let result = try strongSelf.getVideoInfo(
                        from: outputFileURL,
                        usedFrames: usedFrames,
                        videoWidth: Int(videoWidth),
                        videoHeight: Int(videoHeight)
                    )
                    completion(.success(result))
                } catch {
                    SentryLog.warning("[Session Replay] Failed to create video info from file attributes, reason: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failed:
                SentryLog.warning("[Session Replay] Finish writing video failed, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                completion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            case .unknown:
                SentryLog.warning("[Session Replay] Finish writing video with unknown status, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                completion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            @unknown default:
                SentryLog.warning("[Session Replay] Finish writing video failed, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                completion(.failure(SentryOnDemandReplayError.errorRenderingVideo))
            }
        }
    }

    fileprivate func getVideoInfo(from outputFileURL: URL, usedFrames: [SentryReplayFrame], videoWidth: Int, videoHeight: Int) throws -> SentryVideoInfo {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
        guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
            SentryLog.warning("[Session Replay] Failed to read video size from video file, reason: size attribute not found")
            throw SentryOnDemandReplayError.cantReadVideoSize
        }
        guard let start = usedFrames.min(by: { $0.time < $1.time })?.time else {
            SentryLog.warning("[Session Replay] Failed to read video start time from used frames, reason: no frames found")
            throw SentryOnDemandReplayError.cantReadVideoStartTime
        }
        let duration = TimeInterval(usedFrames.count / self.frameRate)
        return SentryVideoInfo(
            path: outputFileURL,
            height: videoHeight,
            width: videoWidth,
            duration: duration,
            frameCount: usedFrames.count,
            frameRate: self.frameRate,
            start: start,
            end: start.addingTimeInterval(duration),
            fileSize: fileSize,
            screens: usedFrames.compactMap({ $0.screenName })
        )
    }

    private func createVideoSettings(width: CGFloat, height: CGFloat) -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ] as [String: Any]
        ]
    }
}
// swiftlint:enable type_body_length

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
// swiftlint:enable file_length
