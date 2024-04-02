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

@available(iOS 16.0, tvOS 16.0, *)
@objcMembers
class SentryOnDemandReplay: NSObject {
    private let _outputPath: String
    private let _onDemandDispatchQueue: DispatchQueue
    
    private var _starttime = Date()
    private var _frames = [SentryReplayFrame]()
    private var _currentPixelBuffer: SentryPixelBuffer?
    
    var videoWidth = 200
    var videoHeight = 434
    
    var bitRate = 20_000
    var frameRate = 1
    var cacheMaxSize = UInt.max
    
    init(outputPath: String) {
        self._outputPath = outputPath
        _onDemandDispatchQueue = DispatchQueue(label: "io.sentry.sessionreplay.ondemand")
    }
    
    func addFrame(image: UIImage) {
        _onDemandDispatchQueue.async {
            self.asyncAddFrame(image: image)
        }
    }
    
    private func asyncAddFrame(image: UIImage) {
        guard let data = resizeImage(image, maxWidth: 300)?.pngData() else { return }
        
        let date = Date()
        let interval = date.timeIntervalSince(_starttime)
        let imagePath = (_outputPath as NSString).appendingPathComponent("\(interval).png")
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
        _onDemandDispatchQueue.async {
            while let first = self._frames.first, first.time < date {
                self._frames.removeFirst()
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
            }
        }
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
        let (frames, start, end) = filterFrames(beginning: beginning, end: beginning.addingTimeInterval(duration))
        
        if frames.isEmpty { return }
        
        _currentPixelBuffer = SentryPixelBuffer(size: CGSize(width: videoWidth, height: videoHeight))
        
        videoWriterInput.requestMediaDataWhenReady(on: _onDemandDispatchQueue) { [weak self] in
            guard let self = self else { return }
            
            let imagePath = frames[frameCount]
            
            if let image = UIImage(contentsOfFile: imagePath) {
                let presentTime = CMTime(seconds: Double(frameCount), preferredTimescale: CMTimeScale(self.frameRate))
                
                if self._currentPixelBuffer?.append(image: image, pixelBufferAdapter: pixelBufferAdaptor, presentationTime: presentTime) != true {
                    completion(nil, videoWriter.error)
                    videoWriterInput.markAsFinished()
                }
            }
            
            if frameCount >= frames.count {
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
                            videoInfo = SentryVideoInfo(path: outputFileURL, height: self.videoHeight, width: self.videoWidth, duration: TimeInterval(frames.count / self.frameRate), frameCount: frames.count, frameRate: self.frameRate, start: start, end: end, fileSize: fileSize)
                        } catch {
                            completion(nil, error)
                        }
                    }
                    completion(videoInfo, videoWriter.error)
                }
            }
            
            frameCount += 1
        }
    }
    
    private func filterFrames(beginning: Date, end: Date) -> ([String], firstFrame: Date, lastFrame: Date) {
        var frames = [String]()
        
        var start = Date()
        var actualEnd = Date()
        
        for frame in _frames {
            if frame.time < beginning { continue } else if frame.time > end { break }
            if frame.time < start { start = frame.time }
            
            actualEnd = frame.time
            frames.append(frame.imagePath)
        }
        return (frames, start, actualEnd)
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
