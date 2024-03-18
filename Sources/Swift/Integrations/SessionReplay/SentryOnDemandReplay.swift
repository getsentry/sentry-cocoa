#if canImport(UIKit)
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

class SentryOnDemandReplay {
    private let _outputPath: String
    private let _onDemandDispatchQueue: DispatchQueue
    
    private var _starttime = Date()
    private var _frames = [SentryReplayFrame]()
    private var _currentPixelBuffer: SentryPixelBuffer?
    
    var videoSize = CGSize(width: 200, height: 434)
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
        try? data.write(to: URL(fileURLWithPath: imagePath))
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
        
        let end = beginning.addingTimeInterval(duration)
        var frameCount = 0
        var frames = [String]()
        
        var start = Date()
        var actualEnd = Date()
        
        for frame in _frames {
            if frame.time < beginning { continue } else if frame.time > end { break }
            if frame.time < start { start = frame.time }
            
            actualEnd = frame.time
            frames.append(frame.imagePath)
        }
        
        if frames.isEmpty { return }
        
        _currentPixelBuffer = SentryPixelBuffer(size: videoSize)
        
        videoWriterInput.requestMediaDataWhenReady(on: _onDemandDispatchQueue) { [weak self] in
            guard let self = self else { return }
            
            let imagePath = frames[frameCount]
            if let image = UIImage(contentsOfFile: imagePath) {
                let presentTime = CMTime(seconds: Double(frameCount), preferredTimescale: CMTimeScale(self.frameRate))
                frameCount += 1
                
                if self._currentPixelBuffer?.append(image: image, pixelBufferAdapter: pixelBufferAdaptor, presentationTime: presentTime) != true {
                    completion(nil, videoWriter.error)
                }
            }
            
            if frameCount >= frames.count {
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting {
                    var videoInfo: SentryVideoInfo?
                    if videoWriter.status == .completed {
                        let fileSize = SentryDependencyContainer.sharedInstance().fileManager.fileSize(outputFileURL)
                        videoInfo = SentryVideoInfo(path: outputFileURL, height: Int(self.videoSize.height), width: Int(self.videoSize.width), duration: TimeInterval(frames.count / self.frameRate), frameCount: frames.count, frameRate: self.frameRate, start: start, end: actualEnd, fileSize: fileSize)
                    }
                    completion(videoInfo, videoWriter.error)
                }
            }
        }
    }
    
    private func createVideoSettings() -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ] as [String: Any]
        ]
    }
}

#endif // canImport(UIKit)
