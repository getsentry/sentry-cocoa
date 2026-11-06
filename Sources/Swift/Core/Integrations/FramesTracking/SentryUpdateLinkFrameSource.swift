#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

internal import _SentryPrivate
import Foundation

/// The frame source for OS versions that have `UIUpdateLink`.
///
/// A `CADisplayLink` makes the display and the main thread wake up for every frame for as long as it
/// runs, even when nothing on screen changes. This source only uses callbacks for work that happens
/// anyway. The run loop observer measures how long the main thread is blocked, which is what turns
/// into slow and frozen frames. The UI update observer reports the frame duration of the display
/// and when UIKit produces a frame.
final class SentryUpdateLinkFrameSource: SentryFrameSource {

    // A frame duration outside of these frame rates isn't one of a display, for example when UIKit
    // shortens the deadline of a UI update to present it with low latency.
    private static let validFrameRates: ClosedRange<Double> = 10...240

    private let dateProvider: SentryCurrentDateProvider
    private let runLoopObserver: SentryMainRunLoopActivityObserving
    private let uiUpdateObserver: SentryUIUpdateObserving
    private weak var delegate: SentryFrameSourceDelegate?

    // Accessed only from main thread (UI update observer callback)
    private var frameRate: UInt64 = 60

    /// There is no callback per frame, so the total frame count is calculated from the time that
    /// passed. The main thread writes it, and the threads that start and finish spans read it. They
    /// need to know which work the main thread is on, because no frames are shown during that work.
    private let extrapolatedFrames = SentryMutex(ExtrapolatedFrames())

    var requiresContinuousFrames: Bool {
        get { uiUpdateObserver.requiresContinuousUpdates }
        set { uiUpdateObserver.requiresContinuousUpdates = newValue }
    }

    init(
        dateProvider: SentryCurrentDateProvider,
        runLoopObserver: SentryMainRunLoopActivityObserving,
        uiUpdateObserver: SentryUIUpdateObserving
    ) {
        self.dateProvider = dateProvider
        self.runLoopObserver = runLoopObserver
        self.uiUpdateObserver = uiUpdateObserver
    }

    deinit {
        // This can be deallocated on any thread. Stopping the run loop observer is thread-safe, and
        // the UI update observer cleans up after itself.
        runLoopObserver.stop()
    }

    func start(delegate: SentryFrameSourceDelegate) {
        self.delegate = delegate

        let now = dateProvider.systemTime()
        extrapolatedFrames.withLock { $0.resume(at: now) }

        runLoopObserver.start { [weak self] activity in
            self?.runLoopActivityObserved(activity)
        }
        uiUpdateObserver.start { [weak self] frameDuration in
            self?.uiUpdateObserved(frameDuration: frameDuration)
        }
    }

    func stop() {
        runLoopObserver.stop()
        uiUpdateObserver.stop()

        let now = dateProvider.systemTime()
        extrapolatedFrames.withLock { $0.suspend(at: now) }
    }

    func totalFrames() -> UInt {
        let now = dateProvider.systemTime()
        return extrapolatedFrames.withLock { $0.total(at: now) }
    }

    func resetFrames() {
        let now = dateProvider.systemTime()
        extrapolatedFrames.withLock { $0.reset(at: now) }
    }

    /// The time between two run loop activities is time the main thread spent on one piece of work,
    /// during which it couldn't produce a frame. A `CADisplayLink` sees the same time as the
    /// duration between two of its callbacks, so both frame sources report it the same way.
    ///
    /// This runs multiple times per run loop iteration. It takes one lock that is only ever held
    /// for a few calculations, and must not allocate unless the main thread was blocked.
    private func runLoopActivityObserved(_ activity: CFRunLoopActivity) {
        let now = dateProvider.systemTime()
        let isWaiting = activity == .beforeWaiting

        let delayedFrameStart = extrapolatedFrames.withLock {
            $0.observeRunLoopActivity(at: now, isWaiting: isWaiting)
        }

        guard let delegate else { return }

        if let delayedFrameStart {
            delegate.frameSource(didDelayFrameFrom: delayedFrameStart, to: now, duration: nanosecondsToTimeInterval(now - delayedFrameStart))
        }

        // Without reporting that the main thread is idle, the time the app does nothing would count
        // as the delay of a frame in flight.
        if isWaiting {
            delegate.frameSourceDidBecomeIdle()
        } else {
            delegate.frameSource(didStartFrameAt: now)
        }
    }

    private func uiUpdateObserved(frameDuration: CFTimeInterval) {
        let now = dateProvider.systemTime()

        let reportedFrameRate = frameDuration > 0 ? round(1 / frameDuration) : 0
        if Self.validFrameRates.contains(reportedFrameRate) && UInt64(reportedFrameRate) != frameRate {
            frameRate = UInt64(reportedFrameRate)
            extrapolatedFrames.withLock { [frameRate] in $0.setFrameRate(frameRate, at: now) }
        }

        delegate?.frameSource(didMeasureFrameRate: frameRate, at: now)
        delegate?.frameSourceDidRenderFrame()
    }
}

/// Counts frames by the time that passed instead of by a callback per frame.
///
/// While the main thread waits for work, the display shows one frame per frame duration. While it
/// works on one thing it can't produce a frame, so that work shows at most one frame, no matter how
/// long it takes.
private struct ExtrapolatedFrames {
    private var frames: Double = 0
    /// The system timestamp up to which `frames` is calculated, or `nil` while frames aren't tracked.
    private var countedUntil: UInt64?
    /// When the main thread started the work it's on, or `nil` while it waits for work and before
    /// the first run loop activity.
    private var workStart: UInt64?
    private var frameRate: UInt64 = 60
    private var slowFrameThresholdNanos = ExtrapolatedFrames.slowFrameThresholdNanos(60)

    func total(at systemTimestamp: UInt64) -> UInt {
        UInt(max(0, frames + uncountedFrames(until: systemTimestamp)))
    }

    mutating func resume(at systemTimestamp: UInt64) {
        countedUntil = systemTimestamp
        // The work that started tracking has nothing to compare to, like the first callback of a
        // display link.
        workStart = nil
    }

    mutating func suspend(at systemTimestamp: UInt64) {
        count(until: systemTimestamp)
        countedUntil = nil
        workStart = nil
    }

    mutating func setFrameRate(_ frameRate: UInt64, at systemTimestamp: UInt64) {
        // UIKit reports the frame rate from within work of the main thread. The frames of that work
        // are counted when it ends, because only then it's known whether it delayed a frame.
        count(until: min(workStart ?? systemTimestamp, systemTimestamp))
        self.frameRate = frameRate
        slowFrameThresholdNanos = Self.slowFrameThresholdNanos(frameRate)
    }

    /// - Returns: When the work that ended with this activity started, if it delayed a frame.
    mutating func observeRunLoopActivity(at systemTimestamp: UInt64, isWaiting: Bool) -> UInt64? {
        let endedWorkStart = workStart
        workStart = isWaiting ? nil : systemTimestamp

        guard let endedWorkStart, systemTimestamp > endedWorkStart,
              systemTimestamp - endedWorkStart > slowFrameThresholdNanos else {
            return nil
        }

        if countedUntil != nil {
            count(until: endedWorkStart)
            frames += 1
            countedUntil = systemTimestamp
        }
        return endedWorkStart
    }

    mutating func reset(at systemTimestamp: UInt64) {
        frames = 0
        if countedUntil != nil {
            countedUntil = systemTimestamp
        }
    }

    /// Never moves `countedUntil` back in time, which would count time twice.
    private mutating func count(until systemTimestamp: UInt64) {
        guard let countedUntil, systemTimestamp > countedUntil else { return }

        frames += uncountedFrames(until: systemTimestamp)
        self.countedUntil = systemTimestamp
    }

    private func uncountedFrames(until systemTimestamp: UInt64) -> Double {
        guard let countedUntil, systemTimestamp > countedUntil else { return 0 }

        guard let workStart, systemTimestamp > workStart else {
            return frames(from: countedUntil, to: systemTimestamp)
        }

        // Without the limit, the count would grow while the main thread is blocked, and drop back
        // once the blocked time is counted as one delayed frame.
        let framesBeforeWork = workStart > countedUntil ? frames(from: countedUntil, to: workStart) : 0
        let framesOfWork = min(frames(from: max(countedUntil, workStart), to: systemTimestamp), 1)
        return framesBeforeWork + framesOfWork
    }

    private func frames(from startSystemTimestamp: UInt64, to endSystemTimestamp: UInt64) -> Double {
        nanosecondsToTimeInterval(endSystemTimestamp - startSystemTimestamp) * Double(frameRate)
    }

    private static func slowFrameThresholdNanos(_ frameRate: UInt64) -> UInt64 {
        timeIntervalToNanoseconds(SentryFramesTracker.slowFrameThreshold(frameRate))
    }
}

#endif
