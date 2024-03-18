@_implementationOnly import _SentryPrivate
import Foundation

#if canImport(UIKit)
import UIKit

let SENTRY_REPLAY_FOLDER = "replay"

@objcMembers
class SentrySessionReplay: NSObject {
    private var _rootView: UIView?
    private var _processingScreenshot = false
    private var _displayLink: CADisplayLink?
    private var _lastScreenshot = Date()
    private var _segmentStart: Date?
    private var _sessionStart = Date()
    private var _urlToCache: URL
    private let _replayOptions: SentryReplayOptions
    private var _replayMaker: SentryOnDemandReplay?
    private var _sessionReplayId = SentryId()
    private var _imageCollection = [UIImage]()
    private var _currentSegment = 0
    private var _isFullSession = false
    
    init(replayOptions: SentryReplayOptions) {
        _replayOptions = replayOptions
        _urlToCache = URL(fileURLWithPath: SentryDependencyContainer.sharedInstance().fileManager.sentryPath)
            .appendingPathComponent(SENTRY_REPLAY_FOLDER)
            .appendingPathComponent(UUID().uuidString)
    }
    
    func start(rootView: UIView, isFullSession: Bool) {
        if _displayLink != nil {
            return
        }
        _displayLink = CADisplayLink(target: self, selector: #selector(newFrame(_:) ))
        _displayLink?.add(to: RunLoop.main, forMode: .common)
        _rootView = rootView
        _lastScreenshot = Date()
        _sessionStart = _lastScreenshot
        _segmentStart = nil
        _currentSegment = 0
        _sessionReplayId = SentryId()
                
        if !FileManager.default.fileExists(atPath: _urlToCache.path) {
            try? FileManager.default.createDirectory(at: _urlToCache, withIntermediateDirectories: true)
        }
        
        _replayMaker = SentryOnDemandReplay(outputPath: _urlToCache.path)
        _replayMaker?.bitRate = _replayOptions.replayBitRate
        _replayMaker?.cacheMaxSize = UInt(isFullSession ? _replayOptions.sessionSegmentDuration : _replayOptions.errorReplayDuration)
        _imageCollection.removeAll()
    }
       
    func stop() {
        _displayLink?.invalidate()
        _displayLink = nil
    }
    
    func replayFor(event: Event) {
        if _isFullSession || (event.error == nil && event.exceptions?.count ?? 0 == 0) {
            return
        }
            
        let finalPath = _urlToCache.appendingPathComponent("replay.mp4")
        let replayStart = Date().addingTimeInterval(-_replayOptions.errorReplayDuration)
        
        createAndCapture(finalPath, duration: _replayOptions.errorReplayDuration, startedAt: replayStart)
        promoteToFull()
    }
    
    private func promoteToFull() {
        _isFullSession = true
        _replayMaker?.cacheMaxSize = UInt(_replayOptions.sessionSegmentDuration)
    }
    
    @objc
    private func newFrame(_ sender: CADisplayLink) {
        let now = Date()
        if now.timeIntervalSince(_lastScreenshot) > (1 / Double(_replayOptions.frameRate)) {
            self.takeScreenshot()
            _lastScreenshot = now
            
            if _segmentStart == nil {
                _segmentStart = now
            } else if let _segmentStart,
                      _isFullSession &&
                        now.timeIntervalSince(_segmentStart) >= _replayOptions.sessionSegmentDuration {
                prepareSegmentUntil(now)
            }
        }
    }
    
    private func prepareSegmentUntil(_ date: Date) {
        guard let _segmentStart else { return }
        let from = _segmentStart.timeIntervalSince(_sessionStart)
        let to = date.timeIntervalSince(_sessionStart)
        var pathToSegment = _urlToCache.appendingPathComponent("segments")
        if !FileManager.default.fileExists(atPath: pathToSegment.path) {
            try? FileManager.default.createDirectory(at: pathToSegment, withIntermediateDirectories: true)
        }
        pathToSegment = pathToSegment.appendingPathComponent("\(from)-\(to).mp4")
        let segmentStart = Date().addingTimeInterval(-_replayOptions.sessionSegmentDuration)
        
        createAndCapture(pathToSegment, duration: _replayOptions.sessionSegmentDuration, startedAt: segmentStart)
        
    }

    private func createAndCapture( _ path: URL, duration: TimeInterval, startedAt start: Date ) {
        do {
            try _replayMaker?.createVideoWith(duration: duration, beginning: start, outputFileURL: path, completion: { [weak self] videoInfo, error in
                guard let self = self else { return }
                if let error {
                    print("[SentrySessionReplay] Could not create replay video - \(error)")
                } else if let videoInfo {
                    self.captureSegment(id: self._currentSegment, video: videoInfo, replayType: .session)
                    self._replayMaker?.releaseFramesUntil(videoInfo.end)
                    self._segmentStart = nil
                    self._currentSegment += 1
                }
            })
        } catch {
            print("[SentrySessionReplay] Could not generate session replay segment - \(error)")
        }
    }
    
    private func captureSegment(id: Int, video: SentryVideoInfo, replayType: SentryReplayType) {
        let replayEvent = SentryReplayEvent()
        replayEvent.replayType = replayType
        replayEvent.eventId = self._sessionReplayId
        replayEvent.replayStartTimestamp = video.start
        replayEvent.segmentId = id
        replayEvent.timestamp = video.end
        
        let recording = SentryReplayRecording(segmentId: id, size: video.fileSize, start: video.start, duration: video.duration, frameCount: video.frameCount, frameRate: video.frameRate, height: video.height, width: video.width)
        
        SentrySDK.currentHub().capture(replayEvent, replayRecording: recording, video: video.path)
    }
    
    func takeScreenshot() {
        if _processingScreenshot {
            return
        }

        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }

        guard !_processingScreenshot else {
            return
        }

        _processingScreenshot = true
        defer { _processingScreenshot = false }

        guard let _rootView, let screenshot = SentryViewPhotographer.shared.image(view: _rootView) else { return }

        let backgroundQueue = DispatchQueue.global(qos: .default)
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            self._replayMaker?.addFrame(image: screenshot)
        }
    }
}

#endif // SENTRY_HAS_UIKIT
