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
    
    init(imagePath: String, time: Date) {
        self.imagePath = imagePath
        self.time = time
    }
}

enum SentryOnDemandReplayError: Error {
    case cantReadVideoSize
}

@objcMembers
class SentryOnDemandReplay: NSObject {
    private let _outputPath: String
    private var _currentPixelBuffer: SentryPixelBuffer?
    private var _totalFrames = 0
    private let dateProvider: SentryCurrentDateProvider
    private let workingQueue: SentryDispatchQueueWrapper
    private var _frames = [SentryReplayFrame]()
    
    #if TEST
    //This is exposed only for tests, no need to make it thread safe.
    var frames: [SentryReplayFrame] {
        get { _frames }
        set { _frames = newValue }
    }
    #endif
    
    var videoWidth = 200
    var videoHeight = 434
    var bitRate = 20_000
    var frameRate = 1
    var cacheMaxSize = UInt.max
    
    convenience init(outputPath: String) {
        self.init(outputPath: outputPath,
                  workingQueue: SentryDispatchQueueWrapper(name: "io.sentry.onDemandReplay", attributes: nil),
                  dateProvider: SentryCurrentDateProvider())
    }
    
    init(outputPath: String, workingQueue: SentryDispatchQueueWrapper, dateProvider: SentryCurrentDateProvider) {
        self._outputPath = outputPath
        self.dateProvider = dateProvider
        self.workingQueue = workingQueue
    }
    
    func addFrameAsync(image: UIImage) {
        workingQueue.dispatchAsync({
            self.addFrame(image: image)
        })
    }
    
    private func addFrame(image: UIImage) {
        guard let data = resizeImage(image, maxWidth: 300)?.pngData() else { return }
        
        let date = dateProvider.date()
        let imagePath = (_outputPath as NSString).appendingPathComponent("\(_totalFrames).png")
        do {
            try data.write(to: URL(fileURLWithPath: imagePath))
        } catch {
            print("[SentryOnDemandReplay] Could not save replay frame. Error: \(error)")
            return
        }
        _frames.append(SentryReplayFrame(imagePath: imagePath, time: date))
        
        while _frames.count > cacheMaxSize {
            let first = _frames.removeFirst()
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
        }
        _totalFrames += 1
    }
    
    private func resizeImage(_ originalImage: UIImage, maxWidth: CGFloat) -> UIImage? {
        let originalSize = originalImage.size
        let aspectRatio = originalSize.width / originalSize.height
        
        let newWidth = min(originalSize.width, maxWidth)
        let newHeight = newWidth / aspectRatio
        
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        originalImage.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    func releaseFramesUntil(_ date: Date) {
        workingQueue.dispatchAsync ({
            while let first = self._frames.first, first.time < date {
                self._frames.removeFirst()
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
            }
        })
    }
    
    func createVideoWith(duration: TimeInterval, beginning: Date, outputFileURL: URL, completion: @escaping (SentryVideoInfo?, Error?) -> Void) throws {
        let videoWriter = try AVAssetWriter(url: outputFileURL, fileType: .mov)
        
        let videoSettings = createVideoSettings()
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let bufferAttributes: [String: Any] = [
           String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32ARGB
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: bufferAttributes)
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        var frameCount = 0
        let (framesPaths, start, end) = filterFrames(beginning: beginning, end: beginning.addingTimeInterval(duration))
        
        if framesPaths.isEmpty { return }
        
        _currentPixelBuffer = SentryPixelBuffer(size: CGSize(width: videoWidth, height: videoHeight))
        
        videoWriterInput.requestMediaDataWhenReady(on: workingQueue.queue) { [weak self] in
            guard let self = self else { return }
            
            if frameCount < framesPaths.count {
                let imagePath = framesPaths[frameCount]
                
                if let image = UIImage(contentsOfFile: imagePath) {
                    let presentTime = CMTime(seconds: Double(frameCount), preferredTimescale: CMTimeScale(self.frameRate))
                    guard self._currentPixelBuffer?.append(image: image, pixelBufferAdapter: pixelBufferAdaptor, presentationTime: presentTime) == true else {
                        completion(nil, videoWriter.error)
                        videoWriterInput.markAsFinished()
                        return
                      }
                }
                frameCount += 1
            } else {
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting {
                    var videoInfo: SentryVideoInfo?
                    if videoWriter.status == .completed {
                        do {
                            let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                            guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
                                completion(nil, SentryOnDemandReplayError.cantReadVideoSize)
                                return
                            }
                            videoInfo = SentryVideoInfo(path: outputFileURL, height: self.videoHeight, width: self.videoWidth, duration: TimeInterval(framesPaths.count / self.frameRate), frameCount: framesPaths.count, frameRate: self.frameRate, start: start, end: end, fileSize: fileSize)
                        } catch {
                            completion(nil, error)
                        }
                    }
                    completion(videoInfo, videoWriter.error)
                }
            }
        }
    }
    
    private func filterFrames(beginning: Date, end: Date) -> ([String], start: Date, end: Date) {
        var framesPaths = [String]()
        
        var start = dateProvider.date()
        var actualEnd = start
        workingQueue.dispatchSync({
            for frame in self._frames {
                if frame.time < beginning { continue } else if frame.time > end { break }
                if frame.time < start { start = frame.time }
                
                actualEnd = frame.time
                framesPaths.append(frame.imagePath)
            }
        })
        return (framesPaths, start, actualEnd + TimeInterval((1 / Double(frameRate))))
    }
    
    private func createVideoSettings() -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ] as [String: Any]
        ]
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
