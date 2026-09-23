#if !SDK_V10 && (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import Foundation

/// Detects fully and non-fully blocking app hangs from frame delays on a dedicated watchdog thread.
final class SentryANRTrackerV2: SentryANRTrackerInternalProtocol {
    private enum Lifecycle {
        case notRunning, running, starting, stopping
    }

    private let applicationStateProvider: SentryApplicationStateProvider
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let threadWrapper: SentryThreadWrapper
    private let listeners = SentryMutex(NSHashTable<AnyObject>.weakObjects())
    private let framesTracker: SentryFramesTracker
    private let timeoutInterval: TimeInterval
    private let threadState = SentryMutex<Lifecycle>(.notRunning)

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
    }

    // Keep the watchdog flow together to make the Objective-C conversion directly comparable.
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func detectANRs() {
        let threadID = UUID()
        let shouldRun = threadState.withLock { state in
            threadWrapper.threadStarted(threadID)
            if state != .starting {
                threadWrapper.threadFinished(threadID)
                return false
            }
            Thread.current.name = "io.sentry.app-hang-tracker"
            state = .running
            return true
        }
        guard shouldRun else { return }

        let dateProvider = SentryDependencyContainer.sharedInstance().dateProvider
        var reported = false

        let reportThreshold = 5
        let sleepInterval = timeoutInterval / Double(reportThreshold)
        let sleepIntervalInNanos = timeIntervalToNanoseconds(sleepInterval)
        let timeoutIntervalInNanos = timeIntervalToNanoseconds(timeoutInterval)
        let appHangStoppedInterval = timeIntervalToNanoseconds(sleepInterval * 2)
        let appHangStoppedFrameDelayThreshold = nanosecondsToTimeInterval(appHangStoppedInterval) * 0.2

        // Preserve the unsigned timestamp arithmetic used by the Objective-C implementation.
        var lastAppHangStoppedSystemTime = dateProvider.systemTime() &- timeoutIntervalInNanos
        var lastAppHangStartedSystemTime: UInt64 = 0

        // Exclude background time from an ongoing hang's duration while system time keeps ticking.
        var wasInBackground = false
        var wentToBackgroundSystemTime: UInt64 = 0
        var accumulatedBackgroundTime: UInt64 = 0

        // Cancelling the thread can take up to sleepInterval.
        while true {
            if threadState.withLock({ $0 != .running }) {
                break
            }

            let sleepDeadline = dateProvider.date().addingTimeInterval(timeoutInterval)
            threadWrapper.sleep(forTimeInterval: sleepInterval)

            if threadState.withLock({ $0 != .running }) {
                break
            }

            let isInForeground = applicationStateProvider.isApplicationInForeground
            if !isInForeground {
                SentrySDKLog.debug("Ignoring potential app hangs because the app is in the background")
                if reported && !wasInBackground {
                    wasInBackground = true
                    wentToBackgroundSystemTime = dateProvider.systemTime()
                }
                continue
            }

            if reported && wasInBackground {
                let backgroundTime = dateProvider.systemTime() &- wentToBackgroundSystemTime
                accumulatedBackgroundTime &+= backgroundTime
                wasInBackground = false
            }

            // A suspended app can wake much later than expected. Do not report that as an app hang.
            let deltaFromNowToSleepDeadline = dateProvider.date().timeIntervalSince(sleepDeadline)
            if deltaFromNowToSleepDeadline >= timeoutInterval {
                SentrySDKLog.debug("Ignoring App Hang because the delta is too big: \(deltaFromNowToSleepDeadline).")
                continue
            }

            let nowSystemTime = dateProvider.systemTime()
            if reported {
                let framesDelayStartSystemTime = nowSystemTime &- appHangStoppedInterval
                let framesDelay = framesTracker.getFramesDelay(framesDelayStartSystemTime, endSystemTimestamp: nowSystemTime)
                if framesDelay.delayDuration == -1 {
                    continue
                }

                let appHangStopped = framesDelay.delayDuration < appHangStoppedFrameDelayThreshold
                if appHangStopped {
                    SentrySDKLog.debug("App hang stopped.")

                    // Polling can detect the beginning and end up to one sleep interval late.
                    // Subtract background time, during which system time continues to tick.
                    let elapsedSystemTime = nowSystemTime &- lastAppHangStartedSystemTime
                    let foregroundElapsedTime = elapsedSystemTime > accumulatedBackgroundTime
                        ? elapsedSystemTime - accumulatedBackgroundTime : 0
                    let appHangDurationNanos = timeoutIntervalInNanos &+ foregroundElapsedTime
                    let appHangDurationMinimum = nanosecondsToTimeInterval(appHangDurationNanos &- sleepIntervalInNanos)
                    let appHangDurationMaximum = nanosecondsToTimeInterval(appHangDurationNanos &+ sleepIntervalInNanos)

                    lastAppHangStoppedSystemTime = nowSystemTime
                    reported = false
                    wasInBackground = false
                    accumulatedBackgroundTime = 0

                    // Keep listener work off both the watchdog and main threads.
                    dispatchQueueWrapper.dispatchAsync { [self] in
                        anrStopped(appHangDurationMinimum, to: appHangDurationMaximum)
                    }
                }
                continue
            }

            let lastAppHangLongEnoughInPastThreshold = lastAppHangStoppedSystemTime &+ timeoutIntervalInNanos
            if dateProvider.systemTime() < lastAppHangLongEnoughInPastThreshold {
                SentrySDKLog.debug("Ignoring app hang cause one happened recently.")
                continue
            }

            let frameDelayStartSystemTime = nowSystemTime &- timeoutIntervalInNanos
            let framesDelayForTimeInterval = framesTracker.getFramesDelay(frameDelayStartSystemTime, endSystemTimestamp: nowSystemTime)
            if framesDelayForTimeInterval.delayDuration == -1 {
                continue
            }

            let framesDelayForTimeIntervalInNanos = timeIntervalToNanoseconds(framesDelayForTimeInterval.delayDuration)
            let isFullyBlocking = framesDelayForTimeInterval.framesContributingToDelayCount == 1
            if isFullyBlocking && framesDelayForTimeIntervalInNanos >= timeoutIntervalInNanos {
                SentrySDKLog.warning("App Hang detected: fully-blocking.")
                reported = true
                lastAppHangStartedSystemTime = dateProvider.systemTime()
                anrDetected(.fullyBlocking)
            }

            let nonFullyBlockingFramesDelayThreshold = timeoutInterval * 0.99
            if !isFullyBlocking && framesDelayForTimeInterval.delayDuration > nonFullyBlockingFramesDelayThreshold {
                SentrySDKLog.warning("App Hang detected: non-fully-blocking.")
                reported = true
                lastAppHangStartedSystemTime = dateProvider.systemTime()
                anrDetected(.nonFullyBlocking)
            }
        }

        threadState.withLock { state in
            state = .notRunning
            threadWrapper.threadFinished(threadID)
        }
    }

    private func anrDetected(_ type: SentryANRType) {
        let localListeners = listeners.withLock {
            $0.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate }
        }
        for target in localListeners {
            target.anrDetected(type)
        }
    }

    private func anrStopped(_ hangDurationMinimum: TimeInterval, to hangDurationMaximum: TimeInterval) {
        let targets = listeners.withLock {
            $0.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate }
        }
        let result = SentryANRStoppedResultInternal(minDuration: hangDurationMinimum, maxDuration: hangDurationMaximum)
        for target in targets {
            target.anrStopped(result)
        }
    }

    func addListener(_ listener: SentryANRTrackerInternalDelegate) {
        listeners.withLock { listeners in
            listeners.add(listener)
            threadState.withLock { state in
                if listeners.count > 0 && state == .notRunning {
                    state = .starting
                    // NSThread retained its target. Keep that lifetime and start under the same locks.
                    Thread.detachNewThread { [self] in
                        detectANRs()
                    }
                }
            }
        }
    }

    func removeListener(_ listener: SentryANRTrackerInternalDelegate) {
        listeners.withLock { listeners in
            listeners.remove(listener)
            if listeners.count == 0 {
                stop()
            }
        }
    }

    func clear() {
        listeners.withLock { listeners in
            listeners.removeAllObjects()
            stop()
        }
    }

    private func stop() {
        threadState.withLock { state in
            SentrySDKLog.info("Stopping App Hang detection")
            state = .stopping
        }
    }
}
#endif // !SDK_V10 && UIKit
