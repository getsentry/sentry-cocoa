#if !SDK_V10
import Foundation

/// Detects app hangs with a dedicated watchdog thread that periodically schedules work on the main thread.
final class SentryANRTrackerV1: NSObject, SentryANRTrackerInternalProtocol {
    private enum Lifecycle {
        case notRunning, running, starting, stopping
    }

    private struct PollState {
        var ticksSinceUIUpdate: Int32 = 0
        var reported = false
    }

    private let applicationStateProvider: SentryApplicationStateProvider
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let threadWrapper: SentryThreadWrapper
    private let listenerState = SentryMutex(NSHashTable<AnyObject>.weakObjects())
    private let timeoutInterval: TimeInterval
    private let threadState = SentryMutex<Lifecycle>(.notRunning)

    // Preserve the original Objective-C getter used by the existing deallocation tests.
    @objc private var listeners: NSHashTable<AnyObject> {
        listenerState.withLock { $0 }
    }

    convenience init(timeoutInterval: TimeInterval) {
        let dependencies = SentryDependencyContainer.sharedInstance()
        self.init(timeoutInterval: timeoutInterval,
                  applicationStateProvider: dependencies.applicationStateProvider,
                  dispatchQueueWrapper: dependencies.dispatchQueueWrapper,
                  threadWrapper: dependencies.threadWrapper)
    }

    init(timeoutInterval: TimeInterval,
         applicationStateProvider: SentryApplicationStateProvider,
         dispatchQueueWrapper: SentryDispatchQueueWrapper,
         threadWrapper: SentryThreadWrapper) {
        self.timeoutInterval = timeoutInterval
        self.applicationStateProvider = applicationStateProvider
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.threadWrapper = threadWrapper
        super.init()
    }

    // Keep the watchdog flow together to make the Objective-C conversion directly comparable.
    // swiftlint:disable:next function_body_length
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

        let pollState = SentryMutex(PollState())
        let reportThreshold: Int32 = 5
        let sleepInterval = timeoutInterval / Double(reportThreshold)
        let dateProvider = SentryDependencyContainer.sharedInstance().dateProvider

        // Cancelling the thread can take up to sleepInterval.
        while true {
            if threadState.withLock({ $0 != .running }) {
                break
            }

            let blockDeadline = dateProvider.date().addingTimeInterval(timeoutInterval)
            pollState.withLock { $0.ticksSinceUIUpdate &+= 1 }

            // Preserve the original block ownership and ordering of the individual atomic operations.
            dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [self] in
                pollState.withLock { $0.ticksSinceUIUpdate = 0 }
                let isReported = pollState.withLock { $0.reported }
                if isReported {
                    SentrySDKLog.warning("ANR stopped.")
                    // While an ANR stack trace is being captured, the hang may stop simultaneously.
                    // Offload listener work so it cannot appear in that stack on the main thread.
                    dispatchQueueWrapper.dispatchAsync { [self] in
                        anrStopped()
                    }
                }
                pollState.withLock { $0.reported = false }
            }

            threadWrapper.sleep(forTimeInterval: sleepInterval)

            // A suspended app can wake much later than expected. Do not report that as an app hang.
            let deltaFromNowToBlockDeadline = dateProvider.date().timeIntervalSince(blockDeadline)
            if deltaFromNowToBlockDeadline >= timeoutInterval {
                SentrySDKLog.debug("Ignoring ANR because the delta is too big: \(deltaFromNowToBlockDeadline).")
                continue
            }

            let isReported = pollState.withLock { $0.reported }
            let currentTicks = pollState.withLock { $0.ticksSinceUIUpdate }
            if currentTicks >= reportThreshold && !isReported {
                pollState.withLock { $0.reported = true }

                if !applicationStateProvider.isApplicationInForeground {
                    SentrySDKLog.debug("Ignoring ANR because the app is in the background")
                    continue
                }
                SentrySDKLog.warning("ANR detected.")
                anrDetected()
            }
        }

        threadState.withLock { state in
            state = .notRunning
            threadWrapper.threadFinished(threadID)
        }
    }

    private func anrDetected() {
        let localListeners = listenerState.withLock {
            $0.allObjects.compactMap { $0 as? SentryANRTrackerDelegate }
        }
        for target in localListeners {
            target.anrDetected(type: .unknown)
        }
    }

    private func anrStopped() {
        let targets = listenerState.withLock {
            $0.allObjects.compactMap { $0 as? SentryANRTrackerDelegate }
        }
        for target in targets {
            // V1 intentionally does not measure duration because V2 replaces it.
            target.anrStopped(result: nil)
        }
    }

    func addListener(_ listener: SentryANRTrackerDelegate) {
        listenerState.withLock { listeners in
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

    func removeListener(_ listener: SentryANRTrackerDelegate) {
        listenerState.withLock { listeners in
            listeners.remove(listener)
            if listeners.count == 0 {
                stop()
            }
        }
    }

    func clear() {
        listenerState.withLock { listeners in
            listeners.removeAllObjects()
            stop()
        }
    }

    private func stop() {
        threadState.withLock { state in
            SentrySDKLog.info("Stopping ANR detection")
            state = .stopping
        }
    }
}
#endif // !SDK_V10
