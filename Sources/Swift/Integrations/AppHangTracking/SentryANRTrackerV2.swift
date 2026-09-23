#if !SDK_V10 && (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import Foundation

/// Detects fully and non-fully blocking app hangs from frame delays on a dedicated watchdog thread.
final class SentryANRTrackerV2: SentryANRTrackerInternalProtocol {
    private enum Lifecycle {
        case notRunning, starting, running, stopping
    }

    private struct State {
        var lifecycle: Lifecycle = .notRunning
        let listeners = NSHashTable<AnyObject>.weakObjects()
    }

    /// Only accessed by the watchdog thread.
    private struct DetectionState {
        var reported = false
        var lastStopped: UInt64
        var lastStarted: UInt64 = 0
        var wasInBackground = false
        var wentToBackground: UInt64 = 0
        var accumulatedBackgroundTime: UInt64 = 0
    }

    private let state = SentryMutex(State())
    private let applicationStateProvider: SentryApplicationStateProvider
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let threadWrapper: SentryThreadWrapper
    private let framesTracker: SentryFramesTracker
    private let timeoutInterval: TimeInterval
    private let sleepInterval: TimeInterval
    private let sleepIntervalInNanos: UInt64
    private let timeoutIntervalInNanos: UInt64
    private let appHangStoppedInterval: UInt64
    private let appHangStoppedFrameDelayThreshold: TimeInterval

    convenience init(timeoutInterval: TimeInterval) {
        let dependencies = SentryDependencyContainer.sharedInstance()
        self.init(timeoutInterval: timeoutInterval,
                  applicationStateProvider: dependencies.applicationStateProvider,
                  dispatchQueueWrapper: dependencies.dispatchQueueWrapper,
                  threadWrapper: dependencies.threadWrapper,
                  framesTracker: dependencies.framesTracker)
    }

    init(timeoutInterval: TimeInterval,
         applicationStateProvider: SentryApplicationStateProvider,
         dispatchQueueWrapper: SentryDispatchQueueWrapper,
         threadWrapper: SentryThreadWrapper,
         framesTracker: SentryFramesTracker) {
        self.timeoutInterval = timeoutInterval
        self.applicationStateProvider = applicationStateProvider
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.threadWrapper = threadWrapper
        self.framesTracker = framesTracker
        sleepInterval = timeoutInterval / 5
        sleepIntervalInNanos = timeIntervalToNanoseconds(sleepInterval)
        timeoutIntervalInNanos = timeIntervalToNanoseconds(timeoutInterval)
        appHangStoppedInterval = timeIntervalToNanoseconds(sleepInterval * 2)
        appHangStoppedFrameDelayThreshold = nanosecondsToTimeInterval(appHangStoppedInterval) * 0.2
    }

    private func detectANRs() {
        let threadID = UUID()
        let shouldRun = state.withLock { state in
            threadWrapper.threadStarted(threadID)
            guard state.lifecycle == .starting else {
                threadWrapper.threadFinished(threadID)
                return false
            }
            Thread.current.name = "io.sentry.app-hang-tracker"
            state.lifecycle = .running
            return true
        }
        guard shouldRun else { return }

        defer {
            state.withLock { state in
                state.lifecycle = .notRunning
                threadWrapper.threadFinished(threadID)
            }
        }
        watchFrames()
    }

    private func watchFrames() {
        let dateProvider = SentryDependencyContainer.sharedInstance().dateProvider
        // Preserve the unsigned timestamp arithmetic used by the Objective-C implementation.
        var detection = DetectionState(lastStopped: dateProvider.systemTime() &- timeoutIntervalInNanos)

        // Stopping the thread can take up to sleepInterval.
        while state.withLock({ $0.lifecycle == .running }) {
            let sleepDeadline = dateProvider.date().addingTimeInterval(timeoutInterval)
            threadWrapper.sleep(forTimeInterval: sleepInterval)
            guard state.withLock({ $0.lifecycle == .running }) else { break }

            guard applicationStateProvider.isApplicationInForeground else {
                SentrySDKLog.debug("Ignoring potential app hangs because the app is in the background")
                if detection.reported && !detection.wasInBackground {
                    detection.wasInBackground = true
                    detection.wentToBackground = dateProvider.systemTime()
                }
                continue
            }
            if detection.reported && detection.wasInBackground {
                detection.accumulatedBackgroundTime &+= dateProvider.systemTime() &- detection.wentToBackground
                detection.wasInBackground = false
            }

            // A suspended app can wake much later than expected. Do not report that as an app hang.
            let delta = dateProvider.date().timeIntervalSince(sleepDeadline)
            if delta >= timeoutInterval {
                SentrySDKLog.debug("Ignoring App Hang because the delta is too big: \(delta).")
                continue
            }

            let now = dateProvider.systemTime()
            if detection.reported {
                checkForRecovery(at: now, detection: &detection)
            } else {
                checkForHang(at: now, dateProvider: dateProvider, detection: &detection)
            }
        }
    }

    private func checkForRecovery(at now: UInt64, detection: inout DetectionState) {
        let framesDelay = framesTracker.getFramesDelay(now &- appHangStoppedInterval, endSystemTimestamp: now)
        guard framesDelay.delayDuration != -1,
              framesDelay.delayDuration < appHangStoppedFrameDelayThreshold else { return }

        SentrySDKLog.debug("App hang stopped.")
        let elapsed = now &- detection.lastStarted
        // Exclude every background period from the ongoing hang's duration.
        let foregroundElapsed = elapsed > detection.accumulatedBackgroundTime
            ? elapsed - detection.accumulatedBackgroundTime : 0
        let duration = timeoutIntervalInNanos &+ foregroundElapsed
        // Polling can detect the beginning and end up to one sleep interval late.
        let minimum = nanosecondsToTimeInterval(duration &- sleepIntervalInNanos)
        let maximum = nanosecondsToTimeInterval(duration &+ sleepIntervalInNanos)

        detection.lastStopped = now
        detection.reported = false
        detection.wasInBackground = false
        detection.accumulatedBackgroundTime = 0

        // Keep listener work off both the watchdog and main threads.
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            self?.anrStopped(minimum: minimum, maximum: maximum)
        }
    }

    private func checkForHang(at now: UInt64, dateProvider: SentryCurrentDateProvider, detection: inout DetectionState) {
        guard dateProvider.systemTime() >= detection.lastStopped &+ timeoutIntervalInNanos else {
            SentrySDKLog.debug("Ignoring app hang cause one happened recently.")
            return
        }
        let framesDelay = framesTracker.getFramesDelay(now &- timeoutIntervalInNanos, endSystemTimestamp: now)
        guard framesDelay.delayDuration != -1 else { return }

        let fullyBlocking = framesDelay.framesContributingToDelayCount == 1
        let type: SentryANRType
        if fullyBlocking && timeIntervalToNanoseconds(framesDelay.delayDuration) >= timeoutIntervalInNanos {
            SentrySDKLog.warning("App Hang detected: fully-blocking.")
            type = .fullyBlocking
        } else if !fullyBlocking && framesDelay.delayDuration > timeoutInterval * 0.99 {
            SentrySDKLog.warning("App Hang detected: non-fully-blocking.")
            type = .nonFullyBlocking
        } else {
            return
        }

        detection.reported = true
        detection.lastStarted = dateProvider.systemTime()
        for listener in listenersSnapshot() {
            listener.anrDetected(type)
        }
    }

    private func listenersSnapshot() -> [SentryANRTrackerInternalDelegate] {
        state.withLock { $0.listeners.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate } }
    }

    private func anrStopped(minimum: TimeInterval, maximum: TimeInterval) {
        let listeners = listenersSnapshot()
        let result = SentryANRStoppedResultInternal(minDuration: minimum, maxDuration: maximum)
        for listener in listeners {
            listener.anrStopped(result)
        }
    }

    func addListener(_ listener: SentryANRTrackerInternalDelegate) {
        let shouldStart = state.withLock { state in
            state.listeners.add(listener)
            guard state.lifecycle == .notRunning else { return false }
            state.lifecycle = .starting
            return true
        }
        if shouldStart {
            // Retain the tracker for the watchdog thread's lifetime, as NSThread's target did.
            Thread.detachNewThread { [self] in
                detectANRs()
            }
        }
    }

    func removeListener(_ listener: SentryANRTrackerInternalDelegate) {
        state.withLock { state in
            state.listeners.remove(listener)
            if state.listeners.count == 0 {
                state.lifecycle = .stopping
            }
        }
    }

    func clear() {
        state.withLock { state in
            state.listeners.removeAllObjects()
            state.lifecycle = .stopping
        }
    }
}
#endif // !SDK_V10 && UIKit
