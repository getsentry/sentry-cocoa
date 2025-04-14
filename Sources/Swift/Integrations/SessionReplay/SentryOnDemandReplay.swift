#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import AVFoundation
import CoreGraphics
import Foundation
import UIKit

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
        SentryLog.debug("[Session Replay] Releasing frames until date: \(date)")
        workingQueue.dispatchAsync ({
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
        })
    }
        
    var oldestFrameDate: Date? {
        return _frames.first?.time
    }
    
    func createVideoWith(beginning: Date, end: Date) throws -> [SentryVideoInfo] {
        let videoFrames = filterFrames(beginning: beginning, end: end)
        var frameCount = 0
        
        var videos = [SentryVideoInfo]()
        
        while frameCount < videoFrames.count {
            let outputFileURL = URL(fileURLWithPath: _outputPath.appending("/\(videoFrames[frameCount].time.timeIntervalSinceReferenceDate).mp4"))
            if let videoInfo = try renderVideo(with: videoFrames, from: &frameCount, at: outputFileURL) {
                videos.append(videoInfo)
            } else {
                frameCount++
            }  
        }
        return videos
    }
    
    private func renderVideo(with videoFrames: [SentryReplayFrame], from: inout Int, at outputFileURL: URL) throws -> SentryVideoInfo? {
        guard from < videoFrames.count, let image = UIImage(contentsOfFile: videoFrames[from].imagePath) else { return nil }
        let videoWidth = image.size.width * CGFloat(videoScale)
        let videoHeight = image.size.height * CGFloat(videoScale)
        
        let videoWriter = try AVAssetWriter(url: outputFileURL, fileType: .mp4)
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: createVideoSettings(width: videoWidth, height: videoHeight))
        
        guard let currentPixelBuffer = SentryPixelBuffer(size: CGSize(width: videoWidth, height: videoHeight), videoWriterInput: videoWriterInput)
        else { throw SentryOnDemandReplayError.cantCreatePixelBuffer }
        
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
            guard videoWriter.status == .writing else {
                videoWriter.cancelWriting()
                result = .failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo )
                group.leave()
                return
            }
            if frameCount >= videoFrames.count {
                result = self.finishVideo(outputFileURL: outputFileURL, usedFrames: usedFrames, videoHeight: Int(videoHeight), videoWidth: Int(videoWidth), videoWriter: videoWriter)
                group.leave()
                return
            }
            let frame = videoFrames[frameCount]
            if let image = UIImage(contentsOfFile: frame.imagePath) {
                if lastImageSize != image.size {
                    result = self.finishVideo(outputFileURL: outputFileURL, usedFrames: usedFrames, videoHeight: Int(videoHeight), videoWidth: Int(videoWidth), videoWriter: videoWriter)
                    group.leave()
                    return
                }
                lastImageSize = image.size
                
                let presentTime = CMTime(seconds: Double(frameCount), preferredTimescale: CMTimeScale(1 / self.frameRate))
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
        let group = DispatchGroup()
        var finishError: Error?
        var result: SentryVideoInfo?
        
        group.enter()
        videoWriter.inputs.forEach { $0.markAsFinished() }
        videoWriter.finishWriting {
            defer { group.leave() }
            if videoWriter.status == .completed {
                do {
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                    guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
                        finishError = SentryOnDemandReplayError.cantReadVideoSize
                        return
                    }
                    guard let start = usedFrames.min(by: { $0.time < $1.time })?.time else { return }
                    let duration = TimeInterval(usedFrames.count / self.frameRate)
                    result = SentryVideoInfo(path: outputFileURL, height: Int(videoHeight), width: Int(videoWidth), duration: duration, frameCount: usedFrames.count, frameRate: self.frameRate, start: start, end: start.addingTimeInterval(duration), fileSize: fileSize, screens: usedFrames.compactMap({ $0.screenName }))
                } catch {
                    finishError = error
                }
            }
        }
        group.wait()
        
        if let finishError = finishError { return .failure(finishError) }
        return .success(result)
    }
    
    private func filterFrames(beginning: Date, end: Date) -> [SentryReplayFrame] {
        var frames = [SentryReplayFrame]()
        //Using dispatch queue as sync mechanism since we need a queue already to generate the video.
        workingQueue.dispatchSync({
            frames = self._frames.filter { $0.time >= beginning && $0.time <= end }
        })
        return frames
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

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
