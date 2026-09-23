#if !SDK_V10
import Foundation

/// Detects app hangs by checking whether the main thread executes a periodically scheduled block.
final class SentryANRTrackerV1: SentryANRTrackerInternalProtocol {
    private enum Lifecycle {
        case notRunning, starting, running, stopping
    }

    private struct State {
        var lifecycle: Lifecycle = .notRunning
        let listeners = NSHashTable<AnyObject>.weakObjects()
    }

    private struct PollState {
        var ticksSinceUIUpdate = 0
        var reported = false
    }

    private let state = SentryMutex(State())
    private let applicationStateProvider: SentryApplicationStateProvider
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let threadWrapper: SentryThreadWrapper
    private let timeoutInterval: TimeInterval

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

        watchMainThread()
    }

    private func watchMainThread() {
        let pollState = SentryMutex(PollState())
        let reportThreshold = 5
        let sleepInterval = timeoutInterval / Double(reportThreshold)
        let dateProvider = SentryDependencyContainer.sharedInstance().dateProvider

        // Stopping the thread can take up to sleepInterval.
        while state.withLock({ $0.lifecycle == .running }) {
            let blockDeadline = dateProvider.date().addingTimeInterval(timeoutInterval)
            pollState.withLock { $0.ticksSinceUIUpdate += 1 }

            dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self else { return }
                let wasReported = pollState.withLock { state in
                    state.ticksSinceUIUpdate = 0
                    let wasReported = state.reported
                    state.reported = false
                    return wasReported
                }
                if wasReported {
                    SentrySDKLog.warning("ANR stopped.")
                    // Keep listener work off the main thread so it cannot appear in a captured hang stack.
                    dispatchQueueWrapper.dispatchAsync { [weak self] in
                        self?.anrStopped()
                    }
                }
            }

            threadWrapper.sleep(forTimeInterval: sleepInterval)

            // A suspended app can wake much later than expected. Do not report that as an app hang.
            let delta = dateProvider.date().timeIntervalSince(blockDeadline)
            if delta >= timeoutInterval {
                SentrySDKLog.debug("Ignoring ANR because the delta is too big: \(delta).")
                continue
            }

            let shouldReport = pollState.withLock { state in
                guard state.ticksSinceUIUpdate >= reportThreshold, !state.reported else { return false }
                state.reported = true
                return true
            }
            if shouldReport {
                guard applicationStateProvider.isApplicationInForeground else {
                    SentrySDKLog.debug("Ignoring ANR because the app is in the background")
                    continue
                }
                SentrySDKLog.warning("ANR detected.")
                for listener in listenersSnapshot() {
                    listener.anrDetected(.unknown)
                }
            }
        }
    }

    private func listenersSnapshot() -> [SentryANRTrackerInternalDelegate] {
        state.withLock { $0.listeners.allObjects.compactMap { $0 as? SentryANRTrackerInternalDelegate } }
    }

    private func anrStopped() {
        for listener in listenersSnapshot() {
            // V1 intentionally does not measure duration. V2 provides duration bounds.
            listener.anrStopped(nil)
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
#endif // !SDK_V10
