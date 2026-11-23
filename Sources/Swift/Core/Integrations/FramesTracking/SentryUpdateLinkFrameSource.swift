#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

internal import _SentryPrivate
internal import SentryNativeUtils
import Foundation

/// The frame source for OS versions that have `UIUpdateLink`.
///
/// A `CADisplayLink` makes the display and the main thread wake up for every frame for as long as it
/// runs, even when nothing on screen changes. This source only uses callbacks for work that happens
/// anyway. The run loop observer measures how long the main thread is blocked, which is what turns
/// into slow and frozen frames. The UI update observer reports the frame duration of the display
/// and every frame UIKit produces.
///
/// The total frame count follows the Android SDK: every delayed frame counts as one frame, and the
/// time outside of delayed frames counts as normal frames at the frame rate of the display, as if
/// the display had rendered a frame for every refresh. This keeps the total comparable to the one a
/// display link counts, and slow and frozen frames can never exceed it.
final class SentryUpdateLinkFrameSource: SentryFrameSource {

    // The frame rate comes from the time UIKit gives a UI update to complete, which normally is the
    // time between two refreshes of the display. It sometimes isn't, for example when UIKit shortens
    // it to present an update with low latency, and then it would convert to a frame rate that no
    // display has. A frame rate outside of this range is ignored, and the last one within it stays.
    private static let validFrameRates: ClosedRange<Double> = 10...240

    /// What the total frame count is made of. Written by the main thread, read by the threads that
    /// start and finish spans.
    private struct State {
        /// Whether time is passing for the count. It doesn't while the source is stopped.
        var isCounting = false
        var frameRate: UInt64 = 60
        var slowFrameThresholdNanos = SentryUpdateLinkFrameSource.slowFrameThresholdNanos(60)
        /// Delayed frames, each of which counts as one frame.
        var delayedFrames: UInt = 0
        /// Normal frames of the time outside of delayed frames, up to `countedUntil`.
        var normalFrames: Double = 0
        /// Until when the time outside of delayed frames is in `normalFrames`.
        var countedUntil: UInt64 = 0
        /// When the main thread started the work it's on, or `nil` while it waits for work and
        /// before the first run loop activity.
        var workStart: UInt64?

        mutating func countNormalFrames(until systemTime: UInt64) {
            if systemTime > countedUntil {
                normalFrames += Double(systemTime - countedUntil) * Double(frameRate) / 1e9
            }
            countedUntil = systemTime
        }
    }

    private let dateProvider: SentryCurrentDateProvider
    private let runLoopObserver: SentryMainRunLoopActivityObserving
    private let uiUpdateObserver: SentryUIUpdateObserving
    private weak var delegate: SentryFrameSourceDelegate?

    private let state = SentryMutex(State())

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
        state.withLock { state in
            // The work that started tracking has nothing to compare to, like the first callback of
            // a display link.
            state.workStart = nil
            state.countedUntil = now
            state.isCounting = true
        }

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
        state.withLock { state in
            if let workStart = state.workStart, now > workStart, now - workStart > state.slowFrameThresholdNanos {
                // The main thread is blocked while tracking stops, which is one delayed frame that
                // nobody reports to the delegate any more.
                state.countNormalFrames(until: workStart)
                state.delayedFrames += 1
                state.countedUntil = now
            } else {
                state.countNormalFrames(until: now)
            }
            state.workStart = nil
            state.isCounting = false
        }
    }

    func totalFrames() -> UInt {
        let now = dateProvider.systemTime()
        return state.withLock { state in
            var total = state.delayedFrames
            var normalFrames = state.normalFrames
            if state.isCounting {
                // The work the main thread is on is a delayed frame in flight when it already took
                // longer than the threshold. Like the Android SDK, that frame counts as one frame.
                // Otherwise the time counts as normal frames.
                if let workStart = state.workStart, now > workStart, now - workStart > state.slowFrameThresholdNanos {
                    if workStart > state.countedUntil {
                        normalFrames += Double(workStart - state.countedUntil) * Double(state.frameRate) / 1e9
                    }
                    total += 1
                } else if now > state.countedUntil {
                    normalFrames += Double(now - state.countedUntil) * Double(state.frameRate) / 1e9
                }
            }
            return total + UInt(normalFrames)
        }
    }

    func resetFrames() {
        let now = dateProvider.systemTime()
        state.withLock { state in
            state.delayedFrames = 0
            state.normalFrames = 0
            state.countedUntil = now
        }
    }

    /// The time between two run loop activities is time the main thread spent on one piece of work,
    /// during which it couldn't produce a frame. A `CADisplayLink` sees the same time as the
    /// duration between two of its callbacks, so both frame sources report it the same way.
    ///
    /// This runs multiple times per run loop iteration. Apart from one uncontended lock, it must
    /// not lock or allocate unless the main thread was blocked.
    private func runLoopActivityObserved(_ activity: CFRunLoopActivity) {
        let now = dateProvider.systemTime()
        let isWaiting = activity == .beforeWaiting

        var delayedFrameStart: UInt64?
        state.withLock { state in
            if let workStart = state.workStart, now > workStart, now - workStart > state.slowFrameThresholdNanos {
                // The time before the delayed frame is normal frames. The delayed frame itself is
                // one frame.
                state.countNormalFrames(until: workStart)
                state.delayedFrames += 1
                state.countedUntil = now
                delayedFrameStart = workStart
            }
            state.workStart = isWaiting ? nil : now
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
        let frameRate: UInt64 = state.withLock { state in
            if Self.validFrameRates.contains(reportedFrameRate) && UInt64(reportedFrameRate) != state.frameRate {
                // Normal frames up to now are at the old frame rate. The work the main thread is
                // on isn't counted yet, because it may turn out to be a delayed frame.
                state.countNormalFrames(until: min(state.workStart ?? now, now))
                state.frameRate = UInt64(reportedFrameRate)
                state.slowFrameThresholdNanos = Self.slowFrameThresholdNanos(state.frameRate)
            }
            return state.frameRate
        }

        delegate?.frameSource(didMeasureFrameRate: frameRate, at: now)
        delegate?.frameSourceDidRenderFrame()
    }

    private static func slowFrameThresholdNanos(_ frameRate: UInt64) -> UInt64 {
        timeIntervalToNanoseconds(SentryFramesTracker.slowFrameThreshold(frameRate))
    }
}

#endif
