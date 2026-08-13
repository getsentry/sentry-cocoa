// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@_spi(Private) @objc public class SentryANRTrackerV1: NSObject, SentryANRTrackerInternalProtocol {

    private enum State {
        case notRunning
        case running
        case starting
        case stopping
    }

    private let crashWrapper: SentryCrashReporter
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let threadWrapper: SentryThreadWrapper
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
            threadWrapper: container.threadWrapper
        )
    }

    @objc
    public init(
        timeoutInterval: TimeInterval,
        crashWrapper: SentryCrashReporter,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        threadWrapper: SentryThreadWrapper
    ) {
        self.timeoutInterval = timeoutInterval
        self.crashWrapper = crashWrapper
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.threadWrapper = threadWrapper
    }

    // swiftlint:disable:next function_body_length
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

        var ticksSinceUiUpdate: Int32 = 0
        var reported = false

        let reportThreshold = 5
        let sleepInterval = timeoutInterval / TimeInterval(reportThreshold)

        let dateProvider = SentryDependencyContainer.sharedInstance().dateProvider

        while true {
            objc_sync_enter(threadLock)
            let shouldBreak = state != .running
            objc_sync_exit(threadLock)
            if shouldBreak { break }

            let blockDeadline = dateProvider.date().addingTimeInterval(timeoutInterval)

            OSAtomicIncrement32(&ticksSinceUiUpdate)

            dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self else { return }
                OSAtomicCompareAndSwap32(ticksSinceUiUpdate, 0, &ticksSinceUiUpdate)

                if reported {
                    SentrySDKLog.warning("ANR stopped.")
                    self.dispatchQueueWrapper.dispatchAsync {
                        self.anrStopped()
                    }
                }

                reported = false
            }

            threadWrapper.sleep(forTimeInterval: sleepInterval)

            let deltaFromNowToBlockDeadline = dateProvider.date().timeIntervalSince(blockDeadline)

            if deltaFromNowToBlockDeadline >= timeoutInterval {
                SentrySDKLog.debug("Ignoring ANR because the delta is too big: \(deltaFromNowToBlockDeadline).")
                continue
            }

            let currentTicks = ticksSinceUiUpdate

            if currentTicks >= reportThreshold && !reported {
                reported = true

                if !crashWrapper.isApplicationInForeground {
                    SentrySDKLog.debug("Ignoring ANR because the app is in the background")
                    continue
                }

                SentrySDKLog.warning("ANR detected.")
                anrDetected()
            }
        }

        objc_sync_enter(threadLock)
        state = .notRunning
        threadWrapper.threadFinished(threadID)
        objc_sync_exit(threadLock)
    }

    private func anrDetected() {
        let localListeners: [SentryANRTrackerInternalDelegate]
        objc_sync_enter(listeners)
        localListeners = listeners.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate }
        objc_sync_exit(listeners)

        for target in localListeners {
            target.anrDetected(.unknown)
        }
    }

    private func anrStopped() {
        let targets: [SentryANRTrackerInternalDelegate]
        objc_sync_enter(listeners)
        targets = listeners.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate }
        objc_sync_exit(listeners)

        for target in targets {
            target.anrStopped(nil)
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
        SentrySDKLog.info("Stopping ANR detection")
        state = .stopping
        objc_sync_exit(threadLock)
    }
}
// swiftlint:enable missing_docs
