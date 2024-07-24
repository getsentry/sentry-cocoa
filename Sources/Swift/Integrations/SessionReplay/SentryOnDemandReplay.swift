#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import AVFoundation
import CoreGraphics
import Foundation
import UIKit

struct SentryReplayFrame {
    let imagePath: String
    let time: Date
    let screenName: String?
}

enum SentryOnDemandReplayError: Error {
    case cantReadVideoSize
}

@objcMembers
class SentryOnDemandReplay: NSObject, SentryReplayVideoMaker {
        
    private let _outputPath: String
    private var _totalFrames = 0
    private let dateProvider: SentryCurrentDateProvider
    private let workingQueue: SentryDispatchQueueWrapper
    private var _frames = [SentryReplayFrame]()
    
    #if TEST || TESTCI || DEBUG
    //This is exposed only for tests, no need to make it thread safe.
    var frames: [SentryReplayFrame] {
        get { _frames }
        set { _frames = newValue }
    }
    #endif // TEST || TESTCI || DEBUG

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
        guard let content = try? FileManager.default.contentsOfDirectory(atPath: outputPath) else { return }
        
        _frames = content.compactMap {
            guard let extensionIndex = $0.lastIndex(of: "."), $0[extensionIndex...] == ".png"
            else { return SentryReplayFrame?.none }
            guard let time = Double($0[..<extensionIndex]) else { return nil }
            return SentryReplayFrame(imagePath: "\(outputPath)/\($0)", time: Date(timeIntervalSinceReferenceDate: time), screenName: nil)
        }.sorted { $0.time < $1.time }
    }
    
    convenience init(outputPath: String) {
        self.init(outputPath: outputPath,
                  workingQueue: SentryDispatchQueueWrapper(name: "io.sentry.onDemandReplay", attributes: nil),
                  dateProvider: SentryCurrentDateProvider())
    }
    
    convenience init(withContentFrom outputPath: String) {
        self.init(withContentFrom: outputPath,
                  workingQueue: SentryDispatchQueueWrapper(name: "io.sentry.onDemandReplay", attributes: nil),
                  dateProvider: SentryCurrentDateProvider())
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
            print("[SentryOnDemandReplay] Could not save replay frame. Error: \(error)")
            return
        }
        _frames.append(SentryReplayFrame(imagePath: imagePath, time: date, screenName: forScreen))
        
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
        workingQueue.dispatchAsync ({
            while let first = self._frames.first, first.time < date {
                self._frames.removeFirst()
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
            }
        })
    }
        
    var oldestFrameDate: Date? {
        return _frames.first?.time
    }
    
    func createVideoWith(beginning: Date, end: Date, completion: @escaping (SentryVideoInfo?, Error?) -> Void) throws {
        var frameCount = 0
        let videoFrames = filterFrames(beginning: beginning, end: end)
        guard let firstFrame = videoFrames.first, let image = UIImage(contentsOfFile: firstFrame.imagePath) else { return }
        let videoWidth = image.size.width * CGFloat(videoScale)
        let videoHeight = image.size.height * CGFloat(videoScale)
        let outputFileURL = URL(fileURLWithPath: _outputPath.appending("/\(beginning.timeIntervalSinceReferenceDate).mp4"))
        let videoWriter = try AVAssetWriter(url: outputFileURL, fileType: .mp4)
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: createVideoSettings(width: videoWidth, height: videoHeight))
        
        let _currentPixelBuffer = SentryPixelBuffer(size: CGSize(width: videoWidth, height: videoHeight), videoWriterInput: videoWriterInput)
        if _currentPixelBuffer == nil { return }
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        var lastVideoSize: CGSize = CGSize(width: videoWidth, height: videoHeight)
        var usedFrames = [SentryReplayFrame]()
        videoWriterInput.requestMediaDataWhenReady(on: workingQueue.queue) { [weak self] in
            guard let self = self, videoWriter.status == .writing else {
                videoWriter.cancelWriting()
                completion(nil, videoWriter.error)
                return
            }
            
            if frameCount < videoFrames.count {
                let frame = videoFrames[frameCount]
                if let image = UIImage(contentsOfFile: frame.imagePath) {
                    if lastVideoSize != image.size {
                        videoWriterInput.markAsFinished()
                        finishVideo(outputFileURL: outputFileURL, usedFrames: usedFrames, videoHeight: Int(videoHeight), videoWidth: Int(videoWidth), videoWriter: videoWriter, completion: completion)
                        
                        workingQueue.dispatchAsyncOnMainQueue {
                            if let previousEnd = usedFrames.min(by: { $0.time > $1.time })?.time {
                                try? self.createVideoWith(beginning: previousEnd.addingTimeInterval(0.5 / Double(self.frameRate)), end: end, completion: completion)
                            }
                        }
                        
                        return
                    }
                    lastVideoSize = image.size
                    
                    let presentTime = CMTime(seconds: Double(frameCount), preferredTimescale: CMTimeScale(1 / self.frameRate))

                    guard _currentPixelBuffer?.append(image: image, presentationTime: presentTime) == true
                    else {
                        completion(nil, videoWriter.error)
                        videoWriter.cancelWriting()
                        return
                    }
                    usedFrames.append(frame)
                }
                frameCount += 1
            } else {
                videoWriterInput.markAsFinished()
                finishVideo(outputFileURL: outputFileURL, usedFrames: usedFrames, videoHeight: Int(videoHeight), videoWidth: Int(videoWidth), videoWriter: videoWriter, completion: completion)
            }
        }
    }
    
    private func finishVideo(outputFileURL: URL, usedFrames: [SentryReplayFrame], videoHeight: Int, videoWidth: Int, videoWriter: AVAssetWriter, completion: @escaping (SentryVideoInfo?, Error?) -> Void) {
        videoWriter.finishWriting {
            var videoInfo: SentryVideoInfo?
            if videoWriter.status == .completed {
                do {
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                    guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
                        completion(nil, SentryOnDemandReplayError.cantReadVideoSize)
                        return
                    }
                    guard let start = usedFrames.min(by: { $0.time < $1.time })?.time else { return }
                    let duration = TimeInterval(usedFrames.count / self.frameRate)
                    videoInfo = SentryVideoInfo(path: outputFileURL, height: Int(videoHeight), width: Int(videoWidth), duration: duration , frameCount: usedFrames.count, frameRate: self.frameRate, start: start, end: start.addingTimeInterval(duration), fileSize: fileSize, screens: usedFrames.compactMap({ $0.screenName }))
                } catch {
                    completion(nil, error)
                }
            }
            completion(videoInfo, videoWriter.error)
        }
    }
    
    private func filterFrames(beginning: Date, end: Date) -> [SentryReplayFrame] {
        var frames = [SentryReplayFrame]()
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
