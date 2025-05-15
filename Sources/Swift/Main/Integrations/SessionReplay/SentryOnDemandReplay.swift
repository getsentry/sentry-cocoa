// swiftlint:disable file_length
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import UIKit

// swiftlint:disable type_body_length
@objcMembers
class SentryOnDemandReplay: NSObject, SentryReplayVideoMaker {
        
    private let _outputPath: String
    private var _totalFrames = 0
    private let dateProvider: SentryCurrentDateProvider
    private let workingQueue: SentryDispatchQueueWrapper
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
        
    init(outputPath: String, workingQueue: SentryDispatchQueueWrapper, dateProvider: SentryCurrentDateProvider) {
        self._outputPath = outputPath
        self.dateProvider = dateProvider
        self.workingQueue = workingQueue
    }
        
    convenience init(withContentFrom outputPath: String, workingQueue: SentryDispatchQueueWrapper, dateProvider: SentryCurrentDateProvider) {
        self.init(outputPath: outputPath, workingQueue: workingQueue, dateProvider: dateProvider)
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

    convenience init(outputPath: String) {
        self.init(outputPath: outputPath,
                  workingQueue: SentryDispatchQueueWrapper(name: "io.sentry.onDemandReplay", attributes: nil),
                  dateProvider: SentryDefaultCurrentDateProvider())
    }
    
    convenience init(withContentFrom outputPath: String) {
        self.init(withContentFrom: outputPath,
                  workingQueue: SentryDispatchQueueWrapper(name: "io.sentry.onDemandReplay", attributes: nil),
                  dateProvider: SentryDefaultCurrentDateProvider())
    }

    func addFrameAsync(image: UIImage, forScreen: String?) {
        workingQueue.dispatchAsync({
            self.addFrame(image: image, forScreen: forScreen)
        })
    }
    
    private func addFrame(image: UIImage, forScreen: String?) {
        SentryLog.debug("[Session Replay] Adding frame to replay, screen: \(forScreen ?? "nil")")
        guard let data = rescaleImage(image)?.pngData() else { 
            SentryLog.error("[Session Replay] Could not rescale image, dropping frame")
            return
        }
        
        let date = dateProvider.date()
        let imagePath = (_outputPath as NSString).appendingPathComponent("\(date.timeIntervalSinceReferenceDate).png")
        do {
            SentryLog.debug("[Session Replay] Saving frame to path: \(imagePath)")
            try data.write(to: URL(fileURLWithPath: imagePath))
        } catch {
            SentryLog.error("[Session Replay] Could not save replay frame. Error: \(error)")
            return
        }
        _frames.append(SentryReplayFrame(imagePath: imagePath, time: date, screenName: forScreen))

        // Remove the oldest frames if the cache size exceeds the maximum size.
        while _frames.count > cacheMaxSize {
            let first = _frames.removeFirst()
            SentryLog.debug("[Session Replay] Removing oldest frame at path: \(first.imagePath)")
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
        }
        _totalFrames += 1
        SentryLog.debug("[Session Replay] Increased total frames to: \(_totalFrames)")
    }
    
    private func rescaleImage(_ originalImage: UIImage) -> UIImage? {
        SentryLog.debug("[Session Replay] Rescaling image with scale: \(originalImage.scale)")
        guard originalImage.scale > 1 else { 
            SentryLog.debug("[Session Replay] Image is already at the correct scale, returning original image")
            return originalImage
        }
        
        UIGraphicsBeginImageContextWithOptions(originalImage.size, false, 1)
        defer { UIGraphicsEndImageContext() }
        
        originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func releaseFramesUntil(_ date: Date) {
        workingQueue.dispatchAsync ({
            SentryLog.debug("[Session Replay] Releasing frames until date: \(date)")
            while let first = self._frames.first, first.time < date {
                self._frames.removeFirst()
                let fileUrl = URL(fileURLWithPath: first.imagePath)
                do {
                    try FileManager.default.removeItem(at: fileUrl)
                    SentryLog.debug("[Session Replay] Removed frame at url: \(fileUrl.path)")
                } catch {
                    SentryLog.error("[Session Replay] Failed to remove frame at: \(fileUrl.path), reason: \(error), ignoring error")
                }
            }
            SentryLog.debug("[Session Replay] Frames released, remaining frames count: \(self._frames.count)")
        })
    }
        
    var oldestFrameDate: Date? {
        return _frames.first?.time
    }
    
    func createVideoWith(beginning: Date, end: Date) throws -> [SentryVideoInfo] {
        SentryLog.debug("[Session Replay] Creating video with beginning: \(beginning), end: \(end)")
        let videoFrames = filterFrames(beginning: beginning, end: end)
        var frameCount = 0
        
        var videos = [SentryVideoInfo]()
        
        while frameCount < videoFrames.count {
            let outputFileURL = URL(fileURLWithPath: _outputPath.appending("/\(videoFrames[frameCount].time.timeIntervalSinceReferenceDate).mp4"))
            SentryLog.debug("[Session Replay] Rendering video with output file URL: \(outputFileURL)")
            if let videoInfo = try renderVideo(with: videoFrames, from: &frameCount, at: outputFileURL) {
                videos.append(videoInfo)
            } else {
                frameCount++
            }
        }
        return videos
    }

    // swiftlint:disable:next function_body_length
    private func renderVideo(with videoFrames: [SentryReplayFrame], from: inout Int, at outputFileURL: URL) throws -> SentryVideoInfo? {
        SentryLog.debug("[Session Replay] Rendering video with \(videoFrames.count) video frames, from index: \(from), output file URL: \(outputFileURL)")
        guard from < videoFrames.count, let image = UIImage(contentsOfFile: videoFrames[from].imagePath) else { 
            SentryLog.error("[Session Replay] Could not render video, reason: frame not found")
            return nil 
        }
        let videoWidth = image.size.width * CGFloat(videoScale)
        let videoHeight = image.size.height * CGFloat(videoScale)
        
        let videoWriter = try AVAssetWriter(url: outputFileURL, fileType: .mp4)
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: createVideoSettings(width: videoWidth, height: videoHeight))
        
        guard let currentPixelBuffer = SentryPixelBuffer(size: CGSize(width: videoWidth, height: videoHeight), videoWriterInput: videoWriterInput) else {
            SentryLog.error("[Session Replay] Failed to render video, reason: pixel buffer creation failed")
            throw SentryOnDemandReplayError.cantCreatePixelBuffer
        }

        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        var lastImageSize: CGSize = image.size
        var usedFrames = [SentryReplayFrame]()
        let group = DispatchGroup()
        
        var result: Result<SentryVideoInfo?, Error>?
        var frameCount = from
        
        group.enter()
        videoWriterInput.requestMediaDataWhenReady(on: workingQueue.queue) {
            SentryLog.debug("[Session Replay] Video writer input is ready, status: \(videoWriter.status)")
            guard videoWriter.status == .writing else {
                SentryLog.error("[Session Replay] Video writer status is not writing, cancelling video writing")
                videoWriter.cancelWriting()
                result = .failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo )
                group.leave()
                return
            }
            if frameCount >= videoFrames.count {
                SentryLog.debug("[Session Replay] Frame count is greater than video frames count, finishing video")
                result = self.finishVideo(outputFileURL: outputFileURL, usedFrames: usedFrames, videoHeight: Int(videoHeight), videoWidth: Int(videoWidth), videoWriter: videoWriter)
                group.leave()
                return
            }
            let frame = videoFrames[frameCount]
            if let image = UIImage(contentsOfFile: frame.imagePath) {
                SentryLog.debug("[Session Replay] Image is ready, size: \(image.size)")
                if lastImageSize != image.size {
                    SentryLog.debug("[Session Replay] Image size has changed, finishing video")
                    result = self.finishVideo(outputFileURL: outputFileURL, usedFrames: usedFrames, videoHeight: Int(videoHeight), videoWidth: Int(videoWidth), videoWriter: videoWriter)
                    group.leave()
                    return
                }
                lastImageSize = image.size
                
                let presentTime = SentryOnDemandReplay.calculatePresentationTime(
                    forFrameAtIndex: frameCount,
                    frameRate: self.frameRate
                ).timeValue
                if currentPixelBuffer.append(image: image, presentationTime: presentTime) != true {
                    videoWriter.cancelWriting()
                    result = .failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo )
                    group.leave()
                    return
                }
                usedFrames.append(frame)
            }
            frameCount += 1
        }
        guard group.wait(timeout: .now() + 2) == .success else { throw SentryOnDemandReplayError.errorRenderingVideo }
        from = frameCount
        
        return try result?.get()
    }
        
    private func finishVideo(outputFileURL: URL, usedFrames: [SentryReplayFrame], videoHeight: Int, videoWidth: Int, videoWriter: AVAssetWriter) -> Result<SentryVideoInfo?, Error> {
        SentryLog.info("[Session Replay] Finishing video with output file URL: \(outputFileURL), used frames count: \(usedFrames.count), video height: \(videoHeight), video width: \(videoWidth)")
        let group = DispatchGroup()
        var finishError: Error?
        var result: SentryVideoInfo?
        
        group.enter()
        videoWriter.inputs.forEach { $0.markAsFinished() }
        videoWriter.finishWriting { [weak self] in
            defer { group.leave() }

            SentryLog.debug("[Session Replay] Finished video writing, status: \(videoWriter.status)")
            guard let strongSelf = self else {
                SentryLog.warning("[Session Replay] On-demand replay is deallocated, completing writing session without output video info")
                return
            }

            switch videoWriter.status {
            case .writing:
                SentryLog.error("[Session Replay] Finish writing video was called with status writing, this is unexpected! Completing with no video info")
            case .cancelled:
                SentryLog.warning("[Session Replay] Finish writing video was cancelled, completing with no video info.")
            case .completed:
                SentryLog.debug("[Session Replay] Finish writing video was completed, creating video info from file attributes.")
                do {
                    result = try strongSelf.getVideoInfo(
                        from: outputFileURL,
                        usedFrames: usedFrames,
                        videoWidth: Int(videoWidth),
                        videoHeight: Int(videoHeight)
                    )
                } catch {
                    SentryLog.warning("[Session Replay] Failed to create video info from file attributes, reason: \(error.localizedDescription)")
                    finishError = error
                }
            case .failed, .unknown:
                SentryLog.warning("[Session Replay] Finish writing video failed, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                finishError = videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo
            @unknown default:
                SentryLog.warning("[Session Replay] Finish writing video failed, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                finishError = videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo
            }
        }
        group.wait()
        
        if let finishError = finishError { return .failure(finishError) }
        return .success(result)
    }
    
    private func filterFrames(beginning: Date, end: Date) -> [SentryReplayFrame] {
        var frames = [SentryReplayFrame]()
        // Using dispatch queue as sync mechanism since we need a queue already to generate the video.
        workingQueue.dispatchSync {
            frames = self._frames.filter { $0.time >= beginning && $0.time <= end }
        }
        return frames
    }

    fileprivate func getVideoInfo(from outputFileURL: URL, usedFrames: [SentryReplayFrame], videoWidth: Int, videoHeight: Int) throws -> SentryVideoInfo {
        SentryLog.debug("[Session Replay] Getting video info from file: \(outputFileURL.path), width: \(videoWidth), height: \(videoHeight), used frames count: \(usedFrames.count)")
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
        guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
            SentryLog.warning("[Session Replay] Failed to read video size from video file, reason: size attribute not found")
            throw SentryOnDemandReplayError.cantReadVideoSize
        }
        let minFrame = usedFrames.min(by: { $0.time < $1.time })
        guard let start = minFrame?.time else {
            // Note: This code path is currently not reached, because the `getVideoInfo` method is only called after the video is successfully created, therefore at least one frame was used.
            // The compiler still requires us to unwrap the optional value, and we do not permit force-unwrapping.
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

    internal func createVideoSettings(width: CGFloat, height: CGFloat) -> [String: Any] {
        return [
            // The codec type for the video. H.264 (AVC) is the most widely supported codec across platforms,
            // including web browsers, QuickTime, VLC, and mobile devices.
            AVVideoCodecKey: AVVideoCodecType.h264,

            // The dimensions of the video frame in pixels.
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,

            // AVVideoCompressionPropertiesKey contains advanced compression settings.
            AVVideoCompressionPropertiesKey: [
                // Specifies the average bit rate used for encoding. A higher bit rate increases visual quality
                // at the cost of file size. Choose a value appropriate for your resolution (e.g., 1 Mbps for 720p).
                AVVideoAverageBitRateKey: bitRate,

                // Selects the H.264 Main profile with an automatic level.
                // This avoids using the Baseline profile, which lacks key features like CABAC entropy coding
                // and causes issues in decoders like VideoToolbox, especially at non-standard frame rates (1 FPS).
                // The Main profile is well supported by both hardware and software decoders.
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,

                // Prevents the use of B-frames (bidirectional predicted frames).
                // B-frames reference both past and future frames, which can break compatibility
                // with certain hardware decoders and make accurate seeking harder, especially in timelapse videos
                // where each frame is independent and must be decodable on its own.
                AVVideoAllowFrameReorderingKey: false,

                // Sets keyframe interval to one I-frame per video segment.
                // This significantly reduces file size (e.g. from 19KB to 9KB) while maintaining
                // acceptable seeking granularity. With our 1 FPS recording, this means a keyframe
                // will be inserted once every 6 seconds of recorded content, but our video segments
                // will never be longer than 5 seconds, resulting in a maximum of 1 I-frame per video.
                AVVideoMaxKeyFrameIntervalKey: 6 // 5 + 1 interval for optimal compression
            ] as [String: Any],

            // Explicitly sets the video color space to ITU-R BT.709 (the standard for HD video).
            // This improves color accuracy and ensures consistent rendering across platforms and browsers,
            // especially when the source content is rendered using UIKit/AppKit (e.g., UIColor, UIImage, UIView).
            // Without these, decoders may guess or default to BT.601, resulting in incorrect gamma or saturation.
            AVVideoColorPropertiesKey: [
                // Specifies the color primaries — i.e., the chromaticities of red, green, and blue.
                // BT.709 is the standard for HD content and matches sRGB color primaries,
                // ensuring accurate color reproduction when rendered on most displays.
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,

                // Defines the transfer function (optical-electrical transfer function).
                // BT.709 matches sRGB gamma (~2.2) and ensures that brightness/contrast levels
                // look correct on most screens and in browsers using HTML5 <video>.
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,

                // Specifies how YUV components are encoded from RGB.
                // BT.709 YCbCr matrix ensures correct conversion and consistent luminance/chrominance scaling.
                // Without this, colors might appear washed out or overly saturated.
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ] as [String: Any]
        ]
    }

    /// Calculates the presentation time for a frame at a given index and frame rate.
    ///
    /// The return value is an `NSValue` containing a `CMTime` object representing the calculated presentation time.
    /// The `CMTime` must be wrapped as this class is exposed to Objective-C via `Sentry-Swift.h`, and Objective-C does not support `CMTime`
    /// as a return value.
    ///
    /// - Parameters:
    ///   - index: Index of the frame, counted from 0.
    ///   - frameRate: Number of frames per second.
    /// - Returns: `NSValue` containing the `CMTime` representing the calculated presentation time. Can be accessed using the `timeValue` property.
    internal static func calculatePresentationTime(forFrameAtIndex index: Int, frameRate: Int) -> NSValue {
        // Generate the presentation time for the current frame using integer math.
        // This avoids floating-point rounding issues and ensures frame-accurate timing,
        // which is critical for AVAssetWriter at low frame rates like 1 FPS.
        // By defining timePerFrame as (1 / frameRate) and multiplying it by the frame index,
        // we guarantee consistent spacing between frames and precise control over the timeline.
        let timePerFrame = CMTimeMake(value: 1, timescale: Int32(frameRate))
        let presentTime = CMTimeMultiply(timePerFrame, multiplier: Int32(index))

        return NSValue(time: presentTime)
    }
}
// swiftlint:enable type_body_length

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
// swiftlint:enable file_length
