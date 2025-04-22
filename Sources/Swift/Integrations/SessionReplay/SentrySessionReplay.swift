import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

enum SessionReplayError: Error {
    case cantCreateReplayDirectory
    case noFramesAvailable
}

@objc
protocol SentrySessionReplayDelegate: NSObjectProtocol {
    func sessionReplayShouldCaptureReplayForError() -> Bool
    func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL)
    func sessionReplayStarted(replayId: SentryId)
    func breadcrumbsForSessionReplay() -> [Breadcrumb]
    func currentScreenNameForSessionReplay() -> String?
}

// swiftlint:disable type_body_length
@objcMembers
class SentrySessionReplay: NSObject {
    private(set) var isFullSession = false
    private(set) var sessionReplayId: SentryId?

    private var urlToCache: URL?
    private var rootView: UIView?

    /// The timestamp of the last screenshot taken used to control the frame rate.
    private var timestampOfLastScreenShot: Date?

    private var videoSegmentStart: Date?
    private var sessionStart: Date?
    private var imageCollection: [UIImage] = []
    private weak var delegate: SentrySessionReplayDelegate?
    private var currentSegmentId = 0
    private var processingScreenshot = false

    /// Indicates if the session has reached the maximum duration.
    private var reachedMaximumDuration = false
    private(set) var isSessionPaused = false
    
    private let replayOptions: SentryReplayOptions
    private let replayMaker: SentryReplayVideoMaker
    private let displayLink: SentryDisplayLinkWrapper
    private let dateProvider: SentryCurrentDateProvider
    private let touchTracker: SentryTouchTracker?
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let lock = NSLock()

    var replayTags: [String: Any]?
    var isRunning = false

    var screenshotProvider: SentryViewScreenshotProvider
    var breadcrumbConverter: SentryReplayBreadcrumbConverter
    
    init(replayOptions: SentryReplayOptions,
         replayFolderPath: URL,
         screenshotProvider: SentryViewScreenshotProvider,
         replayMaker: SentryReplayVideoMaker,
         breadcrumbConverter: SentryReplayBreadcrumbConverter,
         touchTracker: SentryTouchTracker?,
         dateProvider: SentryCurrentDateProvider,
         delegate: SentrySessionReplayDelegate,
         dispatchQueue: SentryDispatchQueueWrapper,
         displayLinkWrapper: SentryDisplayLinkWrapper) {
        self.dispatchQueue = dispatchQueue
        self.replayOptions = replayOptions
        self.dateProvider = dateProvider
        self.delegate = delegate
        self.screenshotProvider = screenshotProvider
        self.displayLink = displayLinkWrapper
        self.urlToCache = replayFolderPath
        self.replayMaker = replayMaker
        self.breadcrumbConverter = breadcrumbConverter
        self.touchTracker = touchTracker
        super.init()
    }
    
    deinit {
        disconnectDisplayLink()
    }

    func start(rootView: UIView, fullSession: Bool) {
        guard !isRunning else {
            SentryLog.warning("[Session Replay] Already running, ignoring request to start")
            return
        }
        connectDisplayLink()
        self.rootView = rootView
        timestampOfLastScreenShot = dateProvider.date()
        self.isRunning = true
        videoSegmentStart = nil
        currentSegmentId = 0
        sessionReplayId = SentryId()
        imageCollection = []

        if fullSession {
            startFullReplay()
        }
    }

    private func startFullReplay() {
        sessionStart = timestampOfLastScreenShot
        isFullSession = true
        
        guard let sessionReplayId = sessionReplayId else { return }
        delegate?.sessionReplayStarted(replayId: sessionReplayId)
    }

    func pauseSessionMode() {
        lock.lock()
        defer { lock.unlock() }
        
        self.isSessionPaused = true
        self.videoSegmentStart = nil
    }
    
    func pause() {
        lock.lock()
        defer { lock.unlock() }
        
        disconnectDisplayLink()
        if isFullSession {
            prepareSegmentUntil(date: dateProvider.date())
        }
        isSessionPaused = false
        isRunning = false
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        
        if isSessionPaused {
            isSessionPaused = false
            return
        }
        
        guard !reachedMaximumDuration else { 
            SentryLog.warning("[Session Replay] Reached maximum duration, ignoring request to resume")
            return
        }
        guard !isRunning else { 
            SentryLog.warning("[Session Replay] Already running, ignoring request to resume")
            return 
        }
        
        videoSegmentStart = nil
        isRunning = true
        connectDisplayLink()
    }

    func captureReplayFor(event: Event) {
        guard isRunning else { return }

        if isFullSession {
            setEventContext(event: event)
            return
        }

        guard event.error != nil || event.exceptions?.isEmpty == false else { 
            SentryLog.warning("[Session Replay] Event is not an error and has no exceptions, ignoring request to capture replay")
            return
        }
        guard captureReplay() else { 
            SentryLog.warning("[Session Replay] Did not capture replay, ignoring request to set event context")
            return
        }
        
        setEventContext(event: event)
    }

    @discardableResult
    func captureReplay() -> Bool {
        SentryLog.debug("[Session Replay] Capturing replay")
        guard isRunning else { 
            SentryLog.warning("[Session Replay] Not running, ignoring request to capture replay")
            return false
        }
        guard !isFullSession else { 
            SentryLog.warning("[Session Replay] Full session, ignoring request to capture replay")
            return true 
        }
        guard delegate?.sessionReplayShouldCaptureReplayForError() == true else {
            SentryLog.warning("[Session Replay] Delegate decided to not capture replay, ignoring request to capture replay")
            return false
        }

        startFullReplay()

        // We want to capture the replay at the end of the error replay duration.
        // The current time is the end of the replay, so we need to subtract the buffer duration to get the start time.
        // To make sure that the first frame is captured we need to subtract half the frame rate.
        let diff = -replayOptions.errorReplayDuration - (Double(replayOptions.frameRate) / 2.0)
        let replayEnd = dateProvider.date()
        let replayStart = replayEnd.addingTimeInterval(diff)

        createAndCapture(startedAt: replayStart, replayType: .buffer)
        return true
    }

    private func setEventContext(event: Event) {
        guard let sessionReplayId = sessionReplayId, event.type != "replay_video" else { 
            SentryLog.warning("[Session Replay] Event is not a replay video, ignoring request to set event context")
            return
        }

        var context = event.context ?? [:]
        context["replay"] = ["replay_id": sessionReplayId.sentryIdString]
        event.context = context

        var tags = ["replayId": sessionReplayId.sentryIdString]
        if let eventTags = event.tags {
            tags.merge(eventTags) { (_, new) in new }
        }
        event.tags = tags
    }

    @objc 
    private func displayLinkDidUpdateAction(_ sender: CADisplayLink) {
        SentryLog.debug("[Session Replay] Display link did update, duration since last trigger: \(sender.targetTimestamp - sender.timestamp)")
        guard let timestampOfLastScreenShot = timestampOfLastScreenShot else {
            return
        }
        // If replay is in session mode but it is paused we dont take screenshots
        guard isRunning && !(isFullSession && isSessionPaused) else {
            SentryLog.debug("[Session Replay] Not running or paused in session mode, ignoring request to take screenshot")
            return
        }

        // Check if the session has reached the maximum duration and if so, pause the capturing
        let now = dateProvider.date()
        if let sessionStart = sessionStart, isFullSession && now.timeIntervalSince(sessionStart) > replayOptions.maximumDuration {
            SentryLog.debug("[Session Replay] Session has reached maximum duration, pausing capturing")
            reachedMaximumDuration = true
            pause()
            return
        }

        // Check if the time since the last screenshot is greater than the frame rate
        // The display link will call all this method at an best-effort rate, therefore we need to ensure that
        // we are actually adhereing the frame rate.
        guard now.timeIntervalSince(timestampOfLastScreenShot) >= Double(1 / replayOptions.frameRate) else {
            return
        }
        takeScreenshot()
        self.timestampOfLastScreenShot = now

        if videoSegmentStart == nil {
            videoSegmentStart = now
        } else if let videoSegmentStart = videoSegmentStart, isFullSession &&
                    now.timeIntervalSince(videoSegmentStart) >= replayOptions.sessionSegmentDuration {
            prepareSegmentUntil(date: now)
        }
    }

    private func prepareSegmentUntil(date: Date) {
        SentryLog.debug("[Session Replay] Preparing segment until date: \(date)")
        createSegmentsCacheDirectory()
        let segmentStart = videoSegmentStart ?? dateProvider.date().addingTimeInterval(-replayOptions.sessionSegmentDuration)
        createAndCapture(startedAt: segmentStart, replayType: .session)
    }

    private func createSegmentsCacheDirectory() {
        guard let urlToCache = urlToCache else {
            SentryLog.error("[Session Replay] No path to cache available")
            return
        }
        let pathToSegmentsCacheDir = urlToCache.appendingPathComponent("segments")

        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: pathToSegmentsCacheDir.path) else {
            // If the directory already exists, we don't need to create it again.
            // Do not log anything here as to reduce noise in logs.
            return
        }

        SentryLog.debug("[Session Replay] Creating session replay segment folder at path: \(pathToSegmentsCacheDir.path)")
        do {
            try fileManager.createDirectory(atPath: pathToSegmentsCacheDir.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            SentryLog.error("[Session Replay] Failed to create session replay segment folder, reason: \(error)")
        }

        // TODO: Figure out why the `pathToSegmentsCacheDir` is not used.
    }

    private func createAndCapture(startedAt: Date, replayType: SentryReplayType) {
        SentryLog.debug("[Session Replay] Creating replay video started at date: \(startedAt), replayType: \(replayType)")

        // Creating a video is heavy and blocks the thread
        // Since this function is always called in the main thread we dispatch it to a background thread.
        dispatchQueue.dispatchAsync {
            do {
                SentryLog.debug("[Session Replay] Starting replay video creation")
                let videos = try self.replayMaker.createVideoWith(beginning: startedAt, end: self.dateProvider.date())
                for video in videos {
                    self.newSegmentAvailable(videoInfo: video, replayType: replayType)
                }
                SentryLog.debug("[Session Replay] Finished replay video creation with \(videos.count) segments")
            } catch {
                SentryLog.error("[Session Replay] Could not create replay video, reason: \(error)")
            }
        }
    }

    private func newSegmentAvailable(videoInfo: SentryVideoInfo, replayType: SentryReplayType) {
        SentryLog.debug("[Session Replay] New segment available for replayType: \(replayType), videoInfo: \(videoInfo)")
        guard let sessionReplayId = sessionReplayId else { return }
        captureSegment(segment: currentSegmentId, video: videoInfo, replayId: sessionReplayId, replayType: replayType)
        replayMaker.releaseFramesUntil(videoInfo.end)
        videoSegmentStart = videoInfo.end
        currentSegmentId++
    }
    
    private func captureSegment(segment: Int, video: SentryVideoInfo, replayId: SentryId, replayType: SentryReplayType) {
        let replayEvent = SentryReplayEvent(eventId: replayId, replayStartTimestamp: video.start, replayType: replayType, segmentId: segment)
        
        replayEvent.sdk = self.replayOptions.sdkInfo
        replayEvent.timestamp = video.end
        replayEvent.urls = video.screens
        
        let breadcrumbs = delegate?.breadcrumbsForSessionReplay() ?? []

        var events = convertBreadcrumbs(breadcrumbs: breadcrumbs, from: video.start, until: video.end)
        if let touchTracker = touchTracker {
            events.append(contentsOf: touchTracker.replayEvents(from: videoSegmentStart ?? video.start, until: video.end))
            touchTracker.flushFinishedEvents()
        }
        
        if segment == 0 {
            if let customOptions = replayTags {
                events.append(SentryRRWebOptionsEvent(timestamp: video.start, customOptions: customOptions))
            } else {
                events.append(SentryRRWebOptionsEvent(timestamp: video.start, options: self.replayOptions))
            }
        }
        
        let recording = SentryReplayRecording(segmentId: segment, video: video, extraEvents: events)

        delegate?.sessionReplayNewSegment(replayEvent: replayEvent, replayRecording: recording, videoUrl: video.path)

        do {
            try FileManager.default.removeItem(at: video.path)
        } catch {
            SentryLog.debug("Could not delete replay segment from disk: \(error.localizedDescription)")
        }
    }
    
    private func convertBreadcrumbs(breadcrumbs: [Breadcrumb], from: Date, until: Date) -> [any SentryRRWebEventProtocol] {
        var filteredResult: [Breadcrumb] = []
        var lastNavigationTime: Date = from.addingTimeInterval(-1)
        
        for breadcrumb in breadcrumbs {
            guard let time = breadcrumb.timestamp, time >= from && time < until else { continue }
            
            // If it's a "navigation" breadcrumb, check the timestamp difference from the previous breadcrumb.
            // Skip any breadcrumbs that have occurred within 50ms of the last one,
            // as these represent child view controllers that don’t need their own navigation breadcrumb.
            if breadcrumb.type == "navigation" {
                if time.timeIntervalSince(lastNavigationTime) < 0.05 { continue }
                lastNavigationTime = time
            }
            filteredResult.append(breadcrumb)
        }
        
        return filteredResult.compactMap(breadcrumbConverter.convert(from:))
    }
    
    private func takeScreenshot() {
        SentryLog.debug("[Session Replay] Taking screenshot")
        guard let rootView = rootView else {
            SentryLog.warning("[Session Replay] No root view available, ignoring request to take screenshot")
            return
        }
        guard !processingScreenshot else {
            SentryLog.debug("[Session Replay] Already processing screenshot, ignoring request to take screenshot")
            return
        }

        lock.lock()
        guard !processingScreenshot else {
            lock.unlock()
            return
        }
        processingScreenshot = true
        lock.unlock()

        // Use the delegate to get the screen name for the current screenshot.
        let screenName = delegate?.currentScreenNameForSessionReplay()
        screenshotProvider.image(view: rootView) { [weak self] screenshot in
            guard let strongSelf = self else {
                SentryLog.warning("[Session Replay] Failed to process screenshot, reason: self is deallocated")
                return
            }
            strongSelf.processScreenshot(image: screenshot, forScreen: screenName)
        }
    }

    private func processScreenshot(image: UIImage, forScreen screen: String?) {
        SentryLog.debug("[Session Replay] Processing screenshot for screen: \(screen ?? "nil")")
        lock.synchronized {
            processingScreenshot = false
            replayMaker.addFrameAsync(image: image, forScreen: screen)
        }
    }

    // - MARK: - Display Link

    func connectDisplayLink() {
        let frameRate = replayOptions.frameRate
        SentryLog.debug("[Session Replay] Connecting display link with frame rate: \(frameRate)")

        if #available(iOS 15.0, *) {
            let preferredFrameRateRange = CAFrameRateRange(minimum: Float(frameRate), maximum: Float(frameRate))
            displayLink.link(withTarget: self, selector: #selector(displayLinkDidUpdateAction(_:)), preferredFrameRateRange: preferredFrameRateRange)
        } else {
            let preferredFramesPerSecond = Int(frameRate)
            displayLink.link(withTarget: self, selector: #selector(displayLinkDidUpdateAction(_:)), preferredFramesPerSecond: preferredFramesPerSecond)
        }
    }

    func disconnectDisplayLink() {
        SentryLog.debug("[Session Replay] Disconnecting display link")
        displayLink.invalidate()
    }
}
// swiftlint:enable type_body_length
#endif
