// swiftlint:disable file_length missing_docs
import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
@_implementationOnly import _SentryPrivate
import UIKit

// swiftlint:disable type_body_length
@objcMembers
@_spi(Private) public class SentrySessionReplay: NSObject {
    public private(set) var isFullSession = false
    public private(set) var sessionReplayId: SentryId?

    private var urlToCache: URL?
    private var rootView: UIView?
    private var lastScreenShot: Date?
    private var nextScreenShot: Date?
    private var videoSegmentStart: Date?
    private var sessionStart: Date?
    private var imageCollection: [UIImage] = []
    private weak var delegate: SentrySessionReplayDelegate?
    private var currentSegmentId = 0
    private var processingScreenshot = false
    private var reachedMaximumDuration = false
    private var replayType = SentryReplayType.buffer
    private(set) var isSessionPaused = false
    
    private let replayOptions: SentryReplayOptions
    private let replayMaker: SentryReplayVideoMaker
    private let dateProvider: SentryCurrentDateProvider
    private let touchTracker: SentryTouchTracker?
    private let lock = NSLock()
    private let captureGuard = SentrySessionReplayCaptureGuard()
    private var adaptiveScreenshotInterval: TimeInterval = 0
    private var deferredScreenshotStart: Date?
    private let screenshotIntervalTolerance: TimeInterval = 0.001
    private var captureRunLoopObserver: CFRunLoopObserver?
    private var didProcessCaptureModeWork = false
    private var isCaptureSchedulerRunning = false
    public var replayTags: [String: Any]?

    var isRunning: Bool {
        isCaptureSchedulerRunning
    }
    
    public var screenshotProvider: SentryViewScreenshotProvider
    public var breadcrumbConverter: SentryReplayBreadcrumbConverter
    
    public init(
        replayOptions: SentryReplayOptions,
        replayFolderPath: URL,
        screenshotProvider: SentryViewScreenshotProvider,
        replayMaker: SentryReplayVideoMaker,
        breadcrumbConverter: SentryReplayBreadcrumbConverter,
        touchTracker: SentryTouchTracker?,
        dateProvider: SentryCurrentDateProvider,
        delegate: SentrySessionReplayDelegate
    ) {
        self.replayOptions = replayOptions
        self.dateProvider = dateProvider
        self.delegate = delegate
        self.screenshotProvider = screenshotProvider
        self.urlToCache = replayFolderPath
        self.replayMaker = replayMaker
        self.breadcrumbConverter = breadcrumbConverter
        self.touchTracker = touchTracker
    }
    
    deinit {
        stopCaptureScheduler()
    }
    
    @objc
    static public func shouldEnableSessionReplay(environmentChecker: SentrySessionReplayEnvironmentCheckerProvider, experimentalOptions: SentryExperimentalOptions) -> Bool {
        // Detect if we are running on iOS 26.0 with Liquid Glass and disable session replay.
        // This needs to be done until masking for session replay is properly supported, as it can lead
        // to PII leaks otherwise.
        if environmentChecker.isReliable() {
            return true
        }
        guard experimentalOptions.enableSessionReplayInUnreliableEnvironment else {
            SentrySDKLog.fatal("[Session Replay] Detected environment potentially causing PII leaks, disabling Session Replay. To override this mechanism, set `options.experimental.enableSessionReplayInUnreliableEnvironment` to `true`")
            return false
        }
        SentrySDKLog.warning("[Session Replay] Detected environment potentially causing PII leaks, but `options.experimental.enableSessionReplayInUnreliableEnvironment` is set to `true`, ignoring and enabling Session Replay.")

        return true
    }
    
    public func start(rootView: UIView?, fullSession: Bool) {
        SentrySDKLog.debug("[Session Replay] Starting session replay with full session: \(fullSession)")
        guard !isRunning else {
            SentrySDKLog.debug("[Session Replay] Session replay is already running, not starting again")
            return
        }
        
        self.rootView = rootView
        let now = dateProvider.date()
        lastScreenShot = now
        adaptiveScreenshotInterval = 0
        deferredScreenshotStart = nil
        scheduleNextScreenshot(after: screenshotInterval, from: now)
        startCaptureScheduler()
        videoSegmentStart = nil
        currentSegmentId = 0
        sessionReplayId = SentryId()
        imageCollection = []
        replayType = fullSession ? .session : .buffer

        if fullSession {
            startFullReplay()
        }
    }

    private func startFullReplay() {
        SentrySDKLog.debug("[Session Replay] Starting full session replay")
        sessionStart = lastScreenShot
        isFullSession = true
        guard let sessionReplayId = sessionReplayId else { return }
        delegate?.sessionReplayStarted(replayId: sessionReplayId)
    }

    public func pauseSessionMode() {
        SentrySDKLog.debug("[Session Replay] Pausing session mode")
        lock.lock()
        defer { lock.unlock() }
        
        self.isSessionPaused = true
        self.videoSegmentStart = nil
    }
    
    public func pause() {
        SentrySDKLog.debug("[Session Replay] Pausing session")
        lock.lock()
        defer { lock.unlock() }
        
        stopCaptureScheduler()
        if isFullSession {
            prepareSegmentUntil(date: dateProvider.date())
        }
        isSessionPaused = false
    }

    public func resume() {
        SentrySDKLog.debug("[Session Replay] Resuming session")
        lock.lock()
        defer { lock.unlock() }
        
        if isSessionPaused {
            isSessionPaused = false
            return
        }
        
        guard !reachedMaximumDuration else { 
            SentrySDKLog.warning("[Session Replay] Reached maximum duration, not resuming")
            return 
        }
        guard !isRunning else { 
            SentrySDKLog.debug("[Session Replay] Session is already running, not resuming")
            return 
        }
        
        videoSegmentStart = nil
        let now = dateProvider.date()
        lastScreenShot = now
        scheduleNextScreenshot(after: screenshotInterval, from: now)
        startCaptureScheduler()
    }

    public func captureReplayFor(event: Event) {
        SentrySDKLog.debug("[Session Replay] Capturing replay for event: \(event)")
        guard isRunning else { 
            SentrySDKLog.debug("[Session Replay] Session replay is not running, not capturing replay")
            return 
        }

        if isFullSession {
            SentrySDKLog.info("[Session Replay] Session replay is in full session mode, setting event context")
            setEventContext(event: event)
            return
        }

        guard (event.error != nil || event.exceptions?.isEmpty == false) && captureReplay(replayType: .buffer) else {
            SentrySDKLog.debug("[Session Replay] Not capturing replay, reason: event is not an error or exceptions are empty")
            return
        }
        
        setEventContext(event: event)
    }

    @discardableResult
    public func captureReplay() -> Bool {
        captureReplay(replayType: .buffer)
    }

    @discardableResult
    func captureReplay(replayType: SentryReplayType) -> Bool {
        guard isRunning else {
            SentrySDKLog.debug("[Session Replay] Session replay is not running, not capturing replay")
            return false
        }
        guard !isFullSession else {
            SentrySDKLog.debug("[Session Replay] Session replay is full, not capturing replay")
            return true
        }

        guard delegate?.sessionReplayShouldCaptureReplayForError() == true else {
            SentrySDKLog.debug("[Session Replay] Not capturing replay, reason: delegate should not capture replay")
            return false
        }

        self.replayType = replayType
        startFullReplay()
        let replayStart = dateProvider.date().addingTimeInterval(-replayOptions.errorReplayDuration - (Double(replayOptions.frameRate) / 2.0))

        createAndCaptureInBackground(startedAt: replayStart, replayType: replayType)
        return true
    }

    private func setEventContext(event: Event) {
        SentrySDKLog.debug("[Session Replay] Setting event context")
        guard let sessionReplayId = sessionReplayId, event.type != "replay_video" else { 
            SentrySDKLog.debug("[Session Replay] Not setting event context, reason: session replay id is nil or event type is replay_video")
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
    private func newFrame(_ sender: Any?) {
        captureFrameIfNeeded()
    }

    private func captureFrameIfNeeded() {
        guard isRunning else { return }

        let now = dateProvider.date()

        if isFullSession && isSessionPaused {
            scheduleNextScreenshot(after: screenshotInterval, from: now)
            return
        }
        
        if let sessionStart = sessionStart, isFullSession && now.timeIntervalSince(sessionStart) > replayOptions.maximumDuration {
            SentrySDKLog.debug("[Session Replay] Reached maximum duration, pausing session")
            reachedMaximumDuration = true
            pause()
            // Notify the delegate that the session replay has ended so it can clear the session replay id.
            delegate?.sessionReplayEnded()
            return
        }

        guard shouldCaptureScreenshot(at: now) else {
            return
        }

        if let rootView = rootView, shouldDeferScreenshot(rootView: rootView, at: now) {
            lastScreenShot = now
            scheduleNextScreenshot(after: SentrySessionReplayCaptureGuard.captureDeferralInterval, from: now)
            return
        }

        guard let captureDuration = takeScreenshot(timestamp: now) else {
            let finishedAt = dateProvider.date()
            lastScreenShot = finishedAt
            scheduleNextScreenshot(after: screenshotInterval, from: finishedAt)
            return
        }

        updateAdaptiveScreenshotInterval(captureDuration)
        let finishedAt = dateProvider.date()
        lastScreenShot = finishedAt
        scheduleNextScreenshot(after: screenshotInterval, from: finishedAt)
        updateVideoSegment(at: now)
    }

    private var screenshotInterval: TimeInterval {
        max(1.0 / Double(replayOptions.frameRate), adaptiveScreenshotInterval)
    }

    private func shouldCaptureScreenshot(at date: Date) -> Bool {
        guard let nextScreenShot = nextScreenShot else { return true }
        return date.timeIntervalSince(nextScreenShot) >= -screenshotIntervalTolerance
    }

    private func scheduleNextScreenshot(after interval: TimeInterval, from date: Date) {
        nextScreenShot = date.addingTimeInterval(interval)
    }

    private func startCaptureScheduler() {
        guard !isCaptureSchedulerRunning else { return }

        isCaptureSchedulerRunning = true
        installCaptureRunLoopObserver()
    }

    private func stopCaptureScheduler() {
        isCaptureSchedulerRunning = false
        didProcessCaptureModeWork = false

        if let captureRunLoopObserver = captureRunLoopObserver {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), captureRunLoopObserver, .commonModes)
            self.captureRunLoopObserver = nil
        }
    }

    private func installCaptureRunLoopObserver() {
        guard captureRunLoopObserver == nil else { return }

        let activities = CFRunLoopActivity.afterWaiting.rawValue
            | CFRunLoopActivity.beforeTimers.rawValue
            | CFRunLoopActivity.beforeSources.rawValue
            | CFRunLoopActivity.beforeWaiting.rawValue
            | CFRunLoopActivity.exit.rawValue
        var context = CFRunLoopObserverContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        captureRunLoopObserver = CFRunLoopObserverCreate(
            kCFAllocatorDefault,
            activities,
            true,
            CFIndex.max,
            { observer, activity, context in
                guard let observer = observer,
                    CFRunLoopObserverIsValid(observer),
                    let context = context
                else { return }
                let sessionReplay = Unmanaged<SentrySessionReplay>.fromOpaque(context).takeUnretainedValue()
                sessionReplay.captureOnRunLoopActivity(
                    activity,
                    in: CFRunLoopCopyCurrentMode(CFRunLoopGetCurrent())
                )
            },
            &context
        )

        if let captureRunLoopObserver = captureRunLoopObserver {
            CFRunLoopAddObserver(CFRunLoopGetMain(), captureRunLoopObserver, .commonModes)
        }
    }

    private func captureOnRunLoopActivity(_ activity: CFRunLoopActivity, in currentMode: CFRunLoopMode?) {
        guard isCaptureSchedulerRunning else { return }
        guard !isInteractiveRunLoopMode(currentMode) else {
            didProcessCaptureModeWork = false
            return
        }

        if activity.contains(.afterWaiting)
            || activity.contains(.beforeTimers)
            || activity.contains(.beforeSources) {
            didProcessCaptureModeWork = true
        } else if activity.contains(.beforeWaiting) || activity.contains(.exit) {
            guard didProcessCaptureModeWork else { return }

            didProcessCaptureModeWork = false
            captureFrameIfNeeded()
        }
    }

    private func isInteractiveRunLoopMode(_ currentMode: CFRunLoopMode?) -> Bool {
        guard let currentMode = currentMode else { return false }
        return CFEqual(currentMode.rawValue, RunLoop.Mode.tracking.rawValue as CFString)
    }

    private func shouldDeferScreenshot(rootView: UIView, at date: Date) -> Bool {
        guard captureGuard.shouldDeferCapture(rootView: rootView) else {
            deferredScreenshotStart = nil
            return false
        }

        if let deferredScreenshotStart = deferredScreenshotStart {
            let deferralDuration = date.timeIntervalSince(deferredScreenshotStart)
            if deferralDuration < SentrySessionReplayCaptureGuard.maximumCaptureDeferralInterval {
                return true
            }

            SentrySDKLog.debug("[Session Replay] Forcing screenshot after deferring for \(deferralDuration)s")
            self.deferredScreenshotStart = nil
            return false
        }

        deferredScreenshotStart = date
        return true
    }

    private func updateAdaptiveScreenshotInterval(_ captureDuration: TimeInterval) {
        guard captureDuration > 0 else { return }

        let baseInterval = 1.0 / Double(replayOptions.frameRate)
        if captureDuration >= SentrySessionReplayCaptureGuard.slowCaptureThreshold {
            let nextInterval = adaptiveScreenshotInterval > 0 ? adaptiveScreenshotInterval * 2 : baseInterval * 2
            adaptiveScreenshotInterval = min(nextInterval, SentrySessionReplayCaptureGuard.maximumAdaptiveCaptureInterval)
            SentrySDKLog.debug("[Session Replay] Screenshot capture took \(captureDuration)s, backing off to \(adaptiveScreenshotInterval)s")
        } else if adaptiveScreenshotInterval > 0 {
            let nextInterval = adaptiveScreenshotInterval / 2
            adaptiveScreenshotInterval = nextInterval <= baseInterval ? 0 : nextInterval
        }
    }

    private func updateVideoSegment(at date: Date) {
        if videoSegmentStart == nil {
            videoSegmentStart = date
        } else if let videoSegmentStart = videoSegmentStart, isFullSession &&
                    date.timeIntervalSince(videoSegmentStart) >= replayOptions.sessionSegmentDuration {
            prepareSegmentUntil(date: date)
        }
    }

    private func prepareSegmentUntil(date: Date) {
        SentrySDKLog.debug("[Session Replay] Preparing segment until date: \(date)")
        guard var pathToSegment = urlToCache?.appendingPathComponent("segments") else { 
            SentrySDKLog.debug("[Session Replay] Not preparing segment, reason: could not create path to segments folder")
            return 
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: pathToSegment.path) {
            do {
                try fileManager.createDirectory(atPath: pathToSegment.path, withIntermediateDirectories: true, attributes: nil)
                SentrySDKLog.debug("[Session Replay] Created segments folder at path: \(pathToSegment.path)")
            } catch {
                SentrySDKLog.debug("Can't create session replay segment folder. Error: \(error.localizedDescription)")
                return
            }
        }

        pathToSegment = pathToSegment.appendingPathComponent("\(currentSegmentId).mp4")
        let segmentStart = videoSegmentStart ?? dateProvider.date().addingTimeInterval(-replayOptions.sessionSegmentDuration)

        createAndCaptureInBackground(startedAt: segmentStart, replayType: replayType)
    }

    private func createAndCaptureInBackground(startedAt: Date, replayType: SentryReplayType) {
        SentrySDKLog.debug("[Session Replay] Creating replay video started at date: \(startedAt), replayType: \(replayType)")
        // Creating a video is computationally expensive, therefore perform it on a background queue.
        self.replayMaker.createVideoInBackgroundWith(beginning: startedAt, end: self.dateProvider.date()) { videos in
            SentrySDKLog.debug("[Session Replay] Created replay video with \(videos.count) segments")
            for video in videos {
                self.processNewlyAvailableSegment(videoInfo: video, replayType: replayType)
            }
            SentrySDKLog.debug("[Session Replay] Finished processing replay video with \(videos.count) segments")
        }
    }

    private func processNewlyAvailableSegment(videoInfo: SentryVideoInfo, replayType: SentryReplayType) {
        SentrySDKLog.debug("[Session Replay] Processing new segment available for replayType: \(replayType), videoInfo: \(videoInfo)")
        guard let sessionReplayId = sessionReplayId else {
            SentrySDKLog.warning("[Session Replay] No session replay ID available, ignoring segment.")
            return
        }
        captureSegment(segment: currentSegmentId, video: videoInfo, replayId: sessionReplayId, replayType: replayType)
        replayMaker.releaseFramesUntil(videoInfo.end)
        videoSegmentStart = videoInfo.end
        currentSegmentId++
        SentrySDKLog.debug("[Session Replay] Processed segment, incrementing currentSegmentId to: \(currentSegmentId)")
    }
    
    private func captureSegment(segment: Int, video: SentryVideoInfo, replayId: SentryId, replayType: SentryReplayType) {
        SentrySDKLog.debug("[Session Replay] Capturing segment: \(segment), replayId: \(replayId), replayType: \(replayType)")
        let replayEvent = SentryReplayEvent(eventId: replayId, replayStartTimestamp: video.start, replayType: replayType, segmentId: segment)
        
        replayEvent.sdk = self.replayOptions.sdkInfo
        replayEvent.timestamp = video.end
        replayEvent.urls = video.screens
        
        let breadcrumbs = delegate?.breadcrumbsForSessionReplay() ?? []

        var events = convertBreadcrumbs(breadcrumbs: breadcrumbs, from: video.start, until: video.end)
        if let touchTracker = touchTracker {
            SentrySDKLog.debug("[Session Replay] Adding touch tracker events")
            events.append(contentsOf: touchTracker.replayEvents(from: videoSegmentStart ?? video.start, until: video.end))
            touchTracker.flushFinishedEvents()
        }
        
        if segment == 0 {
            SentrySDKLog.debug("[Session Replay] Adding options event to segment 0")
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
            SentrySDKLog.debug("[Session Replay] Deleted replay segment from disk")
        } catch {
            SentrySDKLog.debug("[Session Replay] Could not delete replay segment from disk: \(error)")
        }
    }
    
    private func convertBreadcrumbs(breadcrumbs: [Breadcrumb], from: Date, until: Date) -> [any SentryRRWebEventProtocol] {
        SentrySDKLog.debug("[Session Replay] Converting breadcrumbs from: \(from) until: \(until)")
        var filteredResult: [Breadcrumb] = []
        var lastNavigationTime: Date = from.addingTimeInterval(-1)
        
        for breadcrumb in breadcrumbs {
            guard let time = breadcrumb.timestamp, time >= from && time < until else { 
                continue
            }
            
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
    
    @discardableResult
    private func takeScreenshot(timestamp: Date) -> TimeInterval? {
        guard let rootView = rootView, !processingScreenshot else { 
            SentrySDKLog.debug("[Session Replay] Not taking screenshot, reason: root view is nil or processing screenshot")
            return nil
        }
        SentrySDKLog.debug("[Session Replay] Taking screenshot of root view: \(rootView)")
        
        lock.lock()
        guard !processingScreenshot else {
            SentrySDKLog.debug("[Session Replay] Not taking screenshot, reason: processing screenshot")
            lock.unlock()
            return nil
        }
        processingScreenshot = true
        lock.unlock()
        
        SentrySDKLog.debug("[Session Replay] Getting screenshot from screenshot provider")
        let screenName = delegate?.currentScreenNameForSessionReplay()
        let captureStart = dateProvider.systemTime()
        screenshotProvider.image(view: rootView) { [weak self] screenshot in
            self?.newImage(timestamp: timestamp, maskedViewImage: screenshot, forScreen: screenName)
        }
        let captureEnd = dateProvider.systemTime()
        guard captureEnd >= captureStart else { return 0 }
        return TimeInterval(captureEnd - captureStart) / 1_000_000_000
    }

    private func newImage(timestamp: Date, maskedViewImage: UIImage, forScreen screen: String?) {
        SentrySDKLog.debug("[Session Replay] New frame available, for screen: \(screen ?? "nil")")
        lock.synchronized {
            processingScreenshot = false
            replayMaker.addFrameAsync(timestamp: timestamp, maskedViewImage: maskedViewImage, forScreen: screen)
        }
    }
}
// swiftlint:enable type_body_length

private final class SentrySessionReplayCaptureGuard {
    static let captureDeferralInterval: TimeInterval = 0.25
    static let maximumCaptureDeferralInterval: TimeInterval = 1
    static let slowCaptureThreshold: TimeInterval = 0.05
    static let maximumAdaptiveCaptureInterval: TimeInterval = 5

    private static let activeAnimationThreshold = 4

    func shouldDeferCapture(rootView: UIView) -> Bool {
        isTrackingRunLoopMode()
            || containsActiveInteraction(in: rootView)
            || activeAnimationCount(in: rootView.layer, upTo: Self.activeAnimationThreshold) >= Self.activeAnimationThreshold
    }

    private func isTrackingRunLoopMode() -> Bool {
        RunLoop.current.currentMode == .tracking
    }

    private func containsActiveInteraction(in view: UIView) -> Bool {
        if let scrollView = view as? UIScrollView, scrollView.isDragging || scrollView.isDecelerating || scrollView.isTracking {
            return true
        }

        if let control = view as? UIControl, control.isTracking {
            return true
        }

        if view.gestureRecognizers?.contains(where: { $0.state == .began || $0.state == .changed }) == true {
            return true
        }

        return view.subviews.contains { containsActiveInteraction(in: $0) }
    }

    private func activeAnimationCount(in layer: CALayer, upTo limit: Int) -> Int {
        var count = layer.animationKeys()?.count ?? 0
        guard count < limit else { return count }

        for sublayer in layer.sublayers ?? [] {
            count += activeAnimationCount(in: sublayer, upTo: limit - count)
            if count >= limit {
                return count
            }
        }

        return count
    }
}

#endif
// swiftlint:enable file_length missing_docs
