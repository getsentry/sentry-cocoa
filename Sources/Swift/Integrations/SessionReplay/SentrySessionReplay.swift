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
    /// Capture pacing state; main-thread confined and deliberately not guarded by `lock` (see its docs).
    private var lastScreenshotAt: Date?
    /// Capture pacing state; main-thread confined and deliberately not guarded by `lock` (see its docs).
    private var nextScreenshotAt: Date?
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
    /// Guards the state shared between the main thread and background queues: segment
    /// bookkeeping (`videoSegmentStart`, `pendingSegmentEnd`, `pendingPauseSegmentEnd`,
    /// `currentSegmentId`), capture scheduler state (`isCaptureSchedulerRunning`,
    /// `didProcessRunLoopWork`, `captureRunLoopObserver`, `nextCaptureActivityCheckAt`) and the
    /// `processingScreenshot`, `isSessionPaused` and `reachedMaximumDuration` flags.
    ///
    /// Capture pacing state (`lastScreenshotAt`, `nextScreenshotAt`, `adaptiveScreenshotInterval`,
    /// `deferredScreenshotStart`) is not guarded by this lock; it is main-thread confined and only
    /// mutated from the run-loop capture scheduler callbacks, blocks dispatched to the main
    /// thread, and `start`.
    private let lock = NSLock()
    private let captureGuard = SentrySessionReplayCaptureGuard()
    /// Capture pacing state; main-thread confined and deliberately not guarded by `lock` (see its docs).
    private var adaptiveScreenshotInterval: TimeInterval = 0
    /// Capture pacing state; main-thread confined and deliberately not guarded by `lock` (see its docs).
    private var deferredScreenshotStart: Date?
    private var captureRunLoopObserver: CFRunLoopObserver?
    private var didProcessRunLoopWork = false
    private var isCaptureSchedulerRunning = false
    private var nextCaptureActivityCheckAt: Date?
    /// Segment end currently being rendered on the replay maker's background queue.
    private var pendingSegmentEnd: Date?
    /// Pause timestamp to process after the current pending segment finishes rendering.
    ///
    /// This preserves the recording interval that ends at pause time without starting a second
    /// segment render while `pendingSegmentEnd` is still in flight.
    private var pendingPauseSegmentEnd: Date?
    public var replayTags: [String: Any]?

    var isRunning: Bool {
        lock.synchronized {
            isCaptureSchedulerRunning
        }
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

    public func start(rootView: UIView?, fullSession: Bool) {
        SentrySDKLog.debug("[Session Replay] Starting session replay with full session: \(fullSession)")
        guard !isRunning else {
            SentrySDKLog.debug("[Session Replay] Session replay is already running, not starting again")
            return
        }

        self.rootView = rootView
        let now = dateProvider.date()
        resetCapturePacing(at: now)
        startCaptureScheduler()
        lock.synchronized {
            videoSegmentStart = nil
            pendingSegmentEnd = nil
            pendingPauseSegmentEnd = nil
            currentSegmentId = 0
        }
        sessionReplayId = SentryId()
        imageCollection = []
        replayType = fullSession ? .session : .buffer

        if fullSession {
            startFullReplay(startedAt: lastScreenshotAt)
        }
    }

    private func startFullReplay(startedAt: Date?) {
        SentrySDKLog.debug("[Session Replay] Starting full session replay")
        sessionStart = startedAt
        lock.synchronized {
            videoSegmentStart = startedAt
        }
        isFullSession = true
        guard let sessionReplayId = sessionReplayId else { return }
        delegate?.sessionReplayStarted(replayId: sessionReplayId)
    }

    public func pauseSessionMode() {
        SentrySDKLog.debug("[Session Replay] Pausing session mode")
        let pauseDate = dateProvider.date()
        lock.synchronized {
            isSessionPaused = true

            if !queuePendingPauseSegmentIfNeeded(at: pauseDate) {
                videoSegmentStart = nil
            }
        }
    }

    public func pause() {
        SentrySDKLog.debug("[Session Replay] Pausing session")
        stopCaptureScheduler()

        let pauseDate = dateProvider.date()
        let shouldPreparePauseSegment = lock.synchronized {
            markPauseSegmentIfNeeded(at: pauseDate)
        }

        if shouldPreparePauseSegment {
            prepareSegmentUntil(date: pauseDate)
        }
    }

    private func markPauseSegmentIfNeeded(at pauseDate: Date) -> Bool {
        guard isFullSession else { return false }
        guard !queuePendingPauseSegmentIfNeeded(at: pauseDate) else { return false }
        return true
    }

    private func queuePendingPauseSegmentIfNeeded(at pauseDate: Date) -> Bool {
        guard isFullSession, pendingSegmentEnd != nil else { return false }
        pendingPauseSegmentEnd = pauseDate
        return true
    }

    public func resume() {
        SentrySDKLog.debug("[Session Replay] Resuming session")
        let shouldStartCaptureScheduler = lock.synchronized {
            prepareCaptureSchedulerResume()
        }

        if shouldStartCaptureScheduler {
            resetCapturePacingAndStartScheduler()
        }
    }

    func resumeSessionMode(restartCaptureScheduler: Bool = true) {
        SentrySDKLog.debug("[Session Replay] Resuming session mode")
        lock.synchronized { isSessionPaused = false }
        guard restartCaptureScheduler else { return }
        resume()
    }

    private func prepareCaptureSchedulerResume() -> Bool {
        if isFullSession && isSessionPaused {
            return false
        }

        guard !reachedMaximumDuration else {
            SentrySDKLog.warning("[Session Replay] Reached maximum duration, not resuming")
            return false
        }
        guard !isCaptureSchedulerRunning else {
            SentrySDKLog.debug("[Session Replay] Session is already running, not resuming")
            return false
        }

        videoSegmentStart = nil
        return true
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
        startFullReplay(startedAt: lastScreenshotAt)
        let replayStart = dateProvider.date().addingTimeInterval(-replayOptions.errorReplayDuration - (Double(replayOptions.frameRate) / 2.0))

        createAndCaptureInBackground(startedAt: replayStart, endedAt: dateProvider.date(), replayType: replayType)
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

    #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
    func captureFrameForTesting(isInteractiveRunLoopMode: Bool = false) {
        captureFrameIfNeeded(isInteractiveRunLoopMode: isInteractiveRunLoopMode)
    }
    #endif

    /// Decides on each run-loop pass whether to capture a screenshot. Stages, in order:
    /// 1. Skip captures while session mode is paused or once the maximum duration is reached.
    /// 2. Skip while a previous screenshot is still being processed.
    /// 3. Throttle view-hierarchy activity checks via `shouldCheckCaptureActivity`.
    /// 4. Apply pacing: interaction captures use the base frame interval, idle captures the
    ///    adaptive backoff interval.
    /// 5. Defer captures while animations are running (up to a maximum deferral), then capture.
    ///
    /// Early exits after stage 1 still call `prepareFullSessionSegmentsIfNeeded` so session
    /// segments are cut on time even when no screenshot is taken.
    // swiftlint:disable function_body_length cyclomatic_complexity
    private func captureFrameIfNeeded(isInteractiveRunLoopMode: Bool = false) {
        guard isRunning else { return }

        let now = dateProvider.date()

        if isFullSession && lock.synchronized({ isSessionPaused }) {
            scheduleNextScreenshot(after: screenshotInterval(), from: now)
            return
        }

        if let sessionStart = sessionStart,
            isFullSession,
            now.timeIntervalSince(sessionStart) > replayOptions.maximumDuration {
            SentrySDKLog.debug("[Session Replay] Reached maximum duration, pausing session")
            lock.synchronized { reachedMaximumDuration = true }
            pause()
            delegate?.sessionReplayEnded()
            return
        }

        guard !lock.synchronized({ processingScreenshot }) else {
            prepareFullSessionSegmentsIfNeeded(until: now)
            return
        }

        guard shouldCheckCaptureActivity(at: now, isInteractiveRunLoopMode: isInteractiveRunLoopMode) else {
            prepareFullSessionSegmentsIfNeeded(until: now)
            return
        }

        let captureActivityReason = isInteractiveRunLoopMode
            ? nil
            : rootView.flatMap { captureGuard.captureActivityReason(rootView: $0, options: replayOptions) }
        let isInteractionCapture = isInteractiveRunLoopMode || captureActivityReason == .interaction

        guard shouldCaptureScreenshot(at: now, usesAdaptiveBackoff: !isInteractionCapture) else {
            let activityCheckInterval: TimeInterval
            if let nextScreenshotAt = nextScreenshotAt {
                activityCheckInterval = max(0, min(baseScreenshotInterval, nextScreenshotAt.timeIntervalSince(now)))
            } else {
                activityCheckInterval = baseScreenshotInterval
            }
            lock.synchronized { nextCaptureActivityCheckAt = now.addingTimeInterval(activityCheckInterval) }
            prepareFullSessionSegmentsIfNeeded(until: now)
            return
        }

        let deferralDecision = screenshotDeferralDecision(
            activityReason: isInteractionCapture ? nil : captureActivityReason,
            at: now
        )
        if deferralDecision == .defer {
            lastScreenshotAt = now
            scheduleNextScreenshot(after: CapturePacing.captureDeferralInterval, from: now)
            prepareFullSessionSegmentsIfNeeded(until: now)
            return
        }

        guard takeScreenshot(timestamp: now, completion: { [weak self] captureDuration in
            guard let self = self else { return }
            self.runOnMainThread { [weak self] in
                guard let self = self else { return }
                defer { self.lock.synchronized { self.processingScreenshot = false } }

                if deferralDecision == .captureAfterDeferral {
                    self.adaptiveScreenshotInterval = 0
                } else if !isInteractionCapture {
                    self.updateAdaptiveScreenshotInterval(captureDuration)
                }

                let finishedAt = self.dateProvider.date()
                self.lastScreenshotAt = finishedAt
                self.scheduleNextScreenshot(after: self.screenshotInterval(usesAdaptiveBackoff: !isInteractionCapture), from: finishedAt)

                let shouldPrepareSegment = self.lock.synchronized {
                    self.isCaptureSchedulerRunning && !self.isSessionPaused && !self.reachedMaximumDuration
                }
                if shouldPrepareSegment {
                    self.prepareFullSessionSegmentsIfNeeded(until: finishedAt)
                }
            }
        }) else {
            let finishedAt = dateProvider.date()
            lastScreenshotAt = finishedAt
            scheduleNextScreenshot(after: screenshotInterval(usesAdaptiveBackoff: !isInteractionCapture), from: finishedAt)
            prepareFullSessionSegmentsIfNeeded(until: finishedAt)
            return
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    private var baseScreenshotInterval: TimeInterval {
        1.0 / Double(replayOptions.frameRate)
    }

    private func resetCapturePacing(at date: Date) {
        lastScreenshotAt = date
        adaptiveScreenshotInterval = 0
        deferredScreenshotStart = nil
        scheduleNextScreenshot(after: screenshotInterval(), from: date)
    }

    private func screenshotInterval(usesAdaptiveBackoff: Bool = true) -> TimeInterval {
        usesAdaptiveBackoff ? max(baseScreenshotInterval, adaptiveScreenshotInterval) : baseScreenshotInterval
    }

    private func shouldCaptureScreenshot(at date: Date, usesAdaptiveBackoff: Bool = true) -> Bool {
        if !usesAdaptiveBackoff, let lastScreenshotAt = lastScreenshotAt {
            return isDeadlineReached(lastScreenshotAt.addingTimeInterval(baseScreenshotInterval), at: date)
        }

        guard let nextScreenshotAt = nextScreenshotAt else { return true }
        return isDeadlineReached(nextScreenshotAt, at: date)
    }

    /// Whether `date` is at or past `deadline`, within ``CapturePacing/screenshotIntervalTolerance``
    /// to absorb run-loop scheduling jitter.
    private func isDeadlineReached(_ deadline: Date, at date: Date) -> Bool {
        date.timeIntervalSince(deadline) >= -CapturePacing.screenshotIntervalTolerance
    }

    private func scheduleNextScreenshot(after interval: TimeInterval, from date: Date) {
        nextScreenshotAt = date.addingTimeInterval(interval)
        lock.synchronized {
            nextCaptureActivityCheckAt = date.addingTimeInterval(min(interval, baseScreenshotInterval))
        }
    }

    private func shouldCheckCaptureActivity(at date: Date, isInteractiveRunLoopMode: Bool) -> Bool {
        if isInteractiveRunLoopMode {
            return shouldCaptureScreenshot(at: date, usesAdaptiveBackoff: false)
        }

        if shouldCaptureScreenshot(at: date) {
            return true
        }

        let nextCaptureActivityCheckAt: Date? = lock.synchronized {
            self.nextCaptureActivityCheckAt
        }
        guard let nextCaptureActivityCheckAt = nextCaptureActivityCheckAt else { return true }
        return isDeadlineReached(nextCaptureActivityCheckAt, at: date)
    }

    private func startCaptureScheduler() {
        let shouldInstallObserver = lock.synchronized {
            guard !isCaptureSchedulerRunning else { return false }

            isCaptureSchedulerRunning = true
            return true
        }
        guard shouldInstallObserver else { return }

        runOnMainThread { [weak self] in
            self?.installCaptureRunLoopObserver()
        }
    }

    private func resetCapturePacingAndStartScheduler() {
        runOnMainThread { [weak self] in
            guard let self = self else { return }

            self.resetCapturePacing(at: self.dateProvider.date())
            self.startCaptureScheduler()
        }
    }

    private func stopCaptureScheduler() {
        let observerToRemove = lock.synchronized {
            isCaptureSchedulerRunning = false
            didProcessRunLoopWork = false
            nextCaptureActivityCheckAt = nil

            let observer = captureRunLoopObserver
            captureRunLoopObserver = nil
            return observer
        }

        if let observerToRemove = observerToRemove {
            CFRunLoopObserverInvalidate(observerToRemove)
            runOnMainThread {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), observerToRemove, .commonModes)
            }
        }
    }

    private func installCaptureRunLoopObserver() {
        let activities = CFRunLoopActivity.afterWaiting.rawValue
            | CFRunLoopActivity.beforeTimers.rawValue
            | CFRunLoopActivity.beforeSources.rawValue
            | CFRunLoopActivity.beforeWaiting.rawValue
            | CFRunLoopActivity.exit.rawValue

        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            activities,
            true,
            CFIndex.max
        ) { [weak self] observer, activity in
            guard let observer = observer,
                CFRunLoopObserverIsValid(observer),
                let self = self
            else { return }

            let shouldCapture = self.lock.synchronized {
                guard self.isCaptureSchedulerRunning else { return false }

                if activity.contains(.afterWaiting)
                    || activity.contains(.beforeTimers)
                    || activity.contains(.beforeSources) {
                    self.didProcessRunLoopWork = true
                    return false
                }

                guard activity.contains(.beforeWaiting) || activity.contains(.exit) else { return false }
                guard self.didProcessRunLoopWork else { return false }

                self.didProcessRunLoopWork = false
                return true
            }
            guard shouldCapture else { return }

            self.captureFrameIfNeeded(isInteractiveRunLoopMode: RunLoop.current.currentMode == .tracking)
        }

        let observerToAdd = lock.synchronized {
            guard captureRunLoopObserver == nil, isCaptureSchedulerRunning else {
                return nil as CFRunLoopObserver?
            }

            captureRunLoopObserver = observer
            return observer
        }

        if let observerToAdd = observerToAdd {
            CFRunLoopAddObserver(CFRunLoopGetMain(), observerToAdd, .commonModes)
        }
    }

    /// Conversion factor between `SentryCurrentDateProvider.systemTime()` nanoseconds and seconds.
    private static let nanosecondsPerSecond: TimeInterval = 1_000_000_000

    /// Tuning constants for the screenshot capture pacing and adaptive backoff policy.
    private enum CapturePacing {
        /// Interval to wait before re-evaluating a capture that was deferred due to ongoing animations.
        static let captureDeferralInterval: TimeInterval = 0.25
        /// Captures taking at least this long double the adaptive screenshot interval;
        /// faster captures halve it again.
        static let slowCaptureThreshold: TimeInterval = 0.05
        /// Upper bound for the adaptive screenshot interval.
        static let maximumAdaptiveCaptureInterval: TimeInterval = 5
        /// Maximum time captures can be deferred due to animations before forcing a capture.
        static let maximumAnimationCaptureDeferralInterval: TimeInterval = 1
        /// Tolerance applied when comparing dates against capture deadlines, to absorb
        /// run-loop scheduling jitter.
        static let screenshotIntervalTolerance: TimeInterval = 0.001
    }

    private enum ScreenshotDeferralDecision {
        case none
        case `defer`
        case captureAfterDeferral
    }

    private func screenshotDeferralDecision(
        activityReason: SentrySessionReplayCaptureGuard.CaptureActivityReason?,
        at date: Date
    ) -> ScreenshotDeferralDecision {
        guard activityReason == .animation else {
            deferredScreenshotStart = nil
            return .none
        }

        guard let deferredScreenshotStart = deferredScreenshotStart else {
            self.deferredScreenshotStart = date
            return .defer
        }

        let deferralDuration = date.timeIntervalSince(deferredScreenshotStart)
        guard deferralDuration >= CapturePacing.maximumAnimationCaptureDeferralInterval else {
            return .defer
        }

        SentrySDKLog.debug("[Session Replay] Forcing screenshot after deferring for \(deferralDuration)s")
        self.deferredScreenshotStart = nil
        return .captureAfterDeferral
    }

    private func updateAdaptiveScreenshotInterval(_ captureDuration: TimeInterval) {
        guard captureDuration > 0 else { return }

        guard captureDuration >= CapturePacing.slowCaptureThreshold else {
            guard adaptiveScreenshotInterval > 0 else { return }

            let nextInterval = adaptiveScreenshotInterval / 2
            adaptiveScreenshotInterval = nextInterval <= baseScreenshotInterval ? 0 : nextInterval
            return
        }

        let nextInterval = adaptiveScreenshotInterval > 0 ? adaptiveScreenshotInterval * 2 : baseScreenshotInterval * 2
        adaptiveScreenshotInterval = min(nextInterval, CapturePacing.maximumAdaptiveCaptureInterval)
        SentrySDKLog.debug("[Session Replay] Screenshot capture took \(captureDuration)s, backing off to \(adaptiveScreenshotInterval)s")
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func prepareFullSessionSegmentsIfNeeded(until date: Date) {
        guard isFullSession else { return }
        let sessionSegmentDuration = replayOptions.sessionSegmentDuration
        guard sessionSegmentDuration > 0 else {
            SentrySDKLog.debug("[Session Replay] Not preparing segment, reason: session segment duration is not positive")
            return
        }

        let segmentBounds: (start: Date, end: Date)? = lock.synchronized {
            guard pendingSegmentEnd == nil else { return nil }
            if videoSegmentStart == nil {
                videoSegmentStart = sessionStart ?? date
            }

            guard let segmentStart = videoSegmentStart,
                date.timeIntervalSince(segmentStart) >= sessionSegmentDuration
            else { return nil }

            let segmentEnd = segmentStart.addingTimeInterval(sessionSegmentDuration)
            pendingSegmentEnd = segmentEnd
            return (segmentStart, segmentEnd)
        }
        guard let (segmentStart, segmentEnd) = segmentBounds else { return }

        if !prepareSegment(from: segmentStart, until: segmentEnd, completion: { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            if self.pendingSegmentEnd == segmentEnd {
                self.pendingSegmentEnd = nil
            }
            let pauseSegmentEnd = self.pendingPauseSegmentEnd
            self.pendingPauseSegmentEnd = nil
            self.lock.unlock()

            if let pauseSegmentEnd = pauseSegmentEnd {
                self.prepareSegmentUntil(date: pauseSegmentEnd)
            }
        }) {
            lock.synchronized {
                if pendingSegmentEnd == segmentEnd {
                    pendingSegmentEnd = nil
                }
            }
        }
    }

    private func prepareSegmentUntil(date: Date) {
        let segmentStart = lock.synchronized {
            videoSegmentStart ?? sessionStart ?? dateProvider.date().addingTimeInterval(-replayOptions.sessionSegmentDuration)
        }
        prepareSegment(from: segmentStart, until: date)
    }

    @discardableResult
    private func prepareSegment(
        from segmentStart: Date,
        until date: Date,
        completion: (() -> Void)? = nil
    ) -> Bool {
        SentrySDKLog.debug("[Session Replay] Preparing segment until date: \(date)")
        guard date > segmentStart else {
            SentrySDKLog.debug("[Session Replay] Not preparing segment, reason: segment duration is empty")
            return false
        }

        guard let pathToSegment = urlToCache?.appendingPathComponent("segments") else {
            SentrySDKLog.debug("[Session Replay] Not preparing segment, reason: could not create path to segments folder")
            return false
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: pathToSegment.path) {
            do {
                try fileManager.createDirectory(atPath: pathToSegment.path, withIntermediateDirectories: true, attributes: nil)
                SentrySDKLog.debug("[Session Replay] Created segments folder at path: \(pathToSegment.path)")
            } catch {
                SentrySDKLog.debug("Can't create session replay segment folder. Error: \(error.localizedDescription)")
                return false
            }
        }

        createAndCaptureInBackground(
            startedAt: segmentStart,
            endedAt: date,
            replayType: replayType,
            completion: completion
        )
        return true
    }

    private func createAndCaptureInBackground(
        startedAt: Date,
        endedAt: Date,
        replayType: SentryReplayType,
        completion: (() -> Void)? = nil
    ) {
        SentrySDKLog.debug("[Session Replay] Creating replay video started at date: \(startedAt), replayType: \(replayType)")
        // Creating a video is computationally expensive, therefore perform it on a background queue.
        self.replayMaker.createVideoInBackgroundWith(beginning: startedAt, end: endedAt) { [weak self] videos in
            guard let self = self else { return }
            SentrySDKLog.debug("[Session Replay] Created replay video with \(videos.count) segments")
            for video in videos {
                self.processNewlyAvailableSegment(videoInfo: video, replayType: replayType)
            }
            completion?()
            SentrySDKLog.debug("[Session Replay] Finished processing replay video with \(videos.count) segments")
        }
    }

    private func processNewlyAvailableSegment(videoInfo: SentryVideoInfo, replayType: SentryReplayType) {
        SentrySDKLog.debug("[Session Replay] Processing new segment available for replayType: \(replayType), videoInfo: \(videoInfo)")
        guard let sessionReplayId = sessionReplayId else {
            SentrySDKLog.warning("[Session Replay] No session replay ID available, ignoring segment.")
            return
        }
        let segmentId = lock.synchronized { () -> Int in
            let segmentId = currentSegmentId
            currentSegmentId++
            return segmentId
        }

        captureSegment(segment: segmentId, video: videoInfo, replayId: sessionReplayId, replayType: replayType)
        replayMaker.releaseFramesUntil(videoInfo.end)
        lock.synchronized {
            // Advance the segment start monotonically; never move it backwards.
            videoSegmentStart = max(videoSegmentStart ?? videoInfo.end, videoInfo.end)
        }
        SentrySDKLog.debug("[Session Replay] Processed segment, incrementing currentSegmentId to: \(segmentId + 1)")
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
            events.append(contentsOf: touchTracker.replayEvents(from: video.start, until: video.end))
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
            // as these represent child view controllers that don't need their own navigation breadcrumb.
            if breadcrumb.type == "navigation" {
                if time.timeIntervalSince(lastNavigationTime) < 0.05 { continue }
                lastNavigationTime = time
            }
            filteredResult.append(breadcrumb)
        }

        return filteredResult.compactMap(breadcrumbConverter.convert(from:))
    }

    private func takeScreenshot(timestamp: Date, completion: @escaping (TimeInterval) -> Void) -> Bool {
        guard let rootView = rootView else {
            SentrySDKLog.debug("[Session Replay] Not taking screenshot, reason: root view is nil")
            return false
        }
        SentrySDKLog.debug("[Session Replay] Taking screenshot of root view: \(rootView)")

        lock.lock()
        guard !processingScreenshot else {
            SentrySDKLog.debug("[Session Replay] Not taking screenshot, reason: processing screenshot")
            lock.unlock()
            return false
        }
        processingScreenshot = true
        lock.unlock()

        SentrySDKLog.debug("[Session Replay] Getting screenshot from screenshot provider")
        let screenName = delegate?.currentScreenNameForSessionReplay()
        let captureStart = dateProvider.systemTime()
        screenshotProvider.image(view: rootView) { [weak self] screenshot in
            guard let self = self else { return }

            let captureEnd = self.dateProvider.systemTime()
            let captureDuration = captureEnd >= captureStart
                ? TimeInterval(captureEnd - captureStart) / Self.nanosecondsPerSecond
                : 0
            self.newImage(timestamp: timestamp, maskedViewImage: screenshot, forScreen: screenName)
            completion(captureDuration)
        }
        return true
    }

    private func newImage(timestamp: Date, maskedViewImage: UIImage, forScreen screen: String?) {
        SentrySDKLog.debug("[Session Replay] New frame available, for screen: \(screen ?? "nil")")
        lock.synchronized {
            replayMaker.addFrameAsync(timestamp: timestamp, maskedViewImage: maskedViewImage, forScreen: screen)
        }
    }

    private func runOnMainThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
// swiftlint:enable type_body_length

#endif
// swiftlint:enable file_length missing_docs
