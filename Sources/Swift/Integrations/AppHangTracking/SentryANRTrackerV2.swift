// swiftlint:disable missing_docs
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import Foundation

@_spi(Private) @objc public class SentryANRTrackerV2: NSObject, SentryANRTrackerInternalProtocol {

    private enum State {
        case notRunning
        case running
        case starting
        case stopping
    }

    private let crashWrapper: SentryCrashReporter
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let threadWrapper: SentryThreadWrapper
    private let framesTracker: SentryFramesTracker
    @objc let listeners = NSHashTable<AnyObject>.weakObjects()
    private let timeoutInterval: TimeInterval
    private let threadLock = NSObject()
    private var state: State = .notRunning

    @objc
    public convenience init(timeoutInterval: TimeInterval) {
        let container = SentryDependencyContainer.sharedInstance()
        self.init(
            timeoutInterval: timeoutInterval,
            crashWrapper: container.crashWrapper,
            dispatchQueueWrapper: container.dispatchQueueWrapper,
            threadWrapper: container.threadWrapper,
            framesTracker: container.framesTracker
        )
    }

    @objc
    public init(
        timeoutInterval: TimeInterval,
        crashWrapper: SentryCrashReporter,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        threadWrapper: SentryThreadWrapper,
        framesTracker: SentryFramesTracker
    ) {
        self.timeoutInterval = timeoutInterval
        self.crashWrapper = crashWrapper
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.threadWrapper = threadWrapper
        self.framesTracker = framesTracker
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func detectANRs() {
        let threadID = UUID()

        objc_sync_enter(threadLock)
        threadWrapper.threadStarted(threadID)

        guard state == .starting else {
            threadWrapper.threadFinished(threadID)
            objc_sync_exit(threadLock)
            return
        }

        Thread.current.name = "io.sentry.app-hang-tracker"
        state = .running
        objc_sync_exit(threadLock)

        let dateProvider = SentryDependencyContainer.sharedInstance().dateProvider

        var reported = false

        let reportThreshold = 5
        let sleepInterval = timeoutInterval / TimeInterval(reportThreshold)
        let sleepIntervalInNanos = timeIntervalToNanoseconds(sleepInterval)
        let timeoutIntervalInNanos = timeIntervalToNanoseconds(timeoutInterval)

        let appHangStoppedInterval = timeIntervalToNanoseconds(sleepInterval * 2)
        let appHangStoppedFrameDelayThreshold = nanosecondsToTimeInterval(appHangStoppedInterval) * 0.2

        var lastAppHangStoppedSystemTime = dateProvider.systemTime() - timeoutIntervalInNanos
        var lastAppHangStartedSystemTime: UInt64 = 0

        var wasInBackground = false
        var wentToBackgroundSystemTime: UInt64 = 0
        var accumulatedBackgroundTime: UInt64 = 0

        while true {
            objc_sync_enter(threadLock)
            let shouldBreak = state != .running
            objc_sync_exit(threadLock)
            if shouldBreak { break }

            let sleepDeadline = dateProvider.date().addingTimeInterval(timeoutInterval)

            threadWrapper.sleep(forTimeInterval: sleepInterval)

            let isInForeground = crashWrapper.isApplicationInForeground

            if !isInForeground {
                SentrySDKLog.debug("Ignoring potential app hangs because the app is in the background")

                if reported && !wasInBackground {
                    wasInBackground = true
                    wentToBackgroundSystemTime = dateProvider.systemTime()
                }

                continue
            }

            if reported && wasInBackground {
                let backgroundTime = dateProvider.systemTime() - wentToBackgroundSystemTime
                accumulatedBackgroundTime += backgroundTime
                wasInBackground = false
            }

            let deltaFromNowToSleepDeadline = dateProvider.date().timeIntervalSince(sleepDeadline)

            if deltaFromNowToSleepDeadline >= timeoutInterval {
                SentrySDKLog.debug("Ignoring App Hang because the delta is too big: \(deltaFromNowToSleepDeadline).")
                continue
            }

            let nowSystemTime = dateProvider.systemTime()

            if reported {
                let framesDelayStartSystemTime = nowSystemTime - appHangStoppedInterval

                let framesDelay = framesTracker.getFramesDelaySPI(
                    framesDelayStartSystemTime,
                    endSystemTimestamp: nowSystemTime
                )

                if framesDelay.delayDuration == -1 {
                    continue
                }

                let appHangStopped = framesDelay.delayDuration < appHangStoppedFrameDelayThreshold

                if appHangStopped {
                    SentrySDKLog.debug("App hang stopped.")

                    let elapsedSystemTime = nowSystemTime - lastAppHangStartedSystemTime
                    let foregroundElapsedTime = elapsedSystemTime > accumulatedBackgroundTime
                        ? elapsedSystemTime - accumulatedBackgroundTime
                        : 0
                    let appHangDurationNanos = timeoutIntervalInNanos + foregroundElapsedTime

                    let appHangDurationMinimum = nanosecondsToTimeInterval(appHangDurationNanos - sleepIntervalInNanos)
                    let appHangDurationMaximum = nanosecondsToTimeInterval(appHangDurationNanos + sleepIntervalInNanos)

                    lastAppHangStoppedSystemTime = nowSystemTime
                    reported = false
                    wasInBackground = false
                    accumulatedBackgroundTime = 0

                    dispatchQueueWrapper.dispatchAsync { [weak self] in
                        self?.anrStopped(hangDurationMinimum: appHangDurationMinimum, hangDurationMaximum: appHangDurationMaximum)
                    }
                }

                continue
            }

            let lastAppHangLongEnoughInPastThreshold = lastAppHangStoppedSystemTime + timeoutIntervalInNanos

            if dateProvider.systemTime() < lastAppHangLongEnoughInPastThreshold {
                SentrySDKLog.debug("Ignoring app hang cause one happened recently.")
                continue
            }

            let frameDelayStartSystemTime = nowSystemTime - timeoutIntervalInNanos

            let framesDelayForTimeInterval = framesTracker.getFramesDelaySPI(
                frameDelayStartSystemTime,
                endSystemTimestamp: nowSystemTime
            )

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
            if !isFullyBlocking
                && framesDelayForTimeInterval.delayDuration > nonFullyBlockingFramesDelayThreshold {
                SentrySDKLog.warning("App Hang detected: non-fully-blocking.")

                reported = true
                lastAppHangStartedSystemTime = dateProvider.systemTime()
                anrDetected(.nonFullyBlocking)
            }
        }

        objc_sync_enter(threadLock)
        state = .notRunning
        threadWrapper.threadFinished(threadID)
        objc_sync_exit(threadLock)
    }

    private func anrDetected(_ type: SentryANRTypeInternal) {
        let localListeners: [SentryANRTrackerInternalDelegate]
        objc_sync_enter(listeners)
        localListeners = listeners.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate }
        objc_sync_exit(listeners)

        for target in localListeners {
            target.anrDetected(type)
        }
    }

    private func anrStopped(hangDurationMinimum: TimeInterval, hangDurationMaximum: TimeInterval) {
        let targets: [SentryANRTrackerInternalDelegate]
        objc_sync_enter(listeners)
        targets = listeners.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate }
        objc_sync_exit(listeners)

        let result = SentryANRStoppedResultInternal(
            minDuration: hangDurationMinimum,
            maxDuration: hangDurationMaximum
        )
        for target in targets {
            target.anrStopped(result)
        }
    }

    @objc
    public func addListener(_ listener: Any) {
        guard let delegate = listener as? SentryANRTrackerInternalDelegate else { return }
        objc_sync_enter(listeners)
        listeners.add(delegate as AnyObject)

        objc_sync_enter(threadLock)
        if listeners.count > 0 && state == .notRunning {
            state = .starting
            Thread.detachNewThread { [weak self] in
                self?.detectANRs()
            }
        }
        objc_sync_exit(threadLock)
        objc_sync_exit(listeners)
    }

    @objc
    public func removeListener(_ listener: Any) {
        guard let delegate = listener as? SentryANRTrackerInternalDelegate else { return }
        objc_sync_enter(listeners)
        listeners.remove(delegate as AnyObject)

        if listeners.count == 0 {
            stop()
        }
        objc_sync_exit(listeners)
    }

    @objc
    public func clear() {
        objc_sync_enter(listeners)
        listeners.removeAllObjects()
        stop()
        objc_sync_exit(listeners)
    }

    private func stop() {
        objc_sync_enter(threadLock)
        SentrySDKLog.info("Stopping App Hang detection")
        state = .stopping
        objc_sync_exit(threadLock)
    }
}
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
