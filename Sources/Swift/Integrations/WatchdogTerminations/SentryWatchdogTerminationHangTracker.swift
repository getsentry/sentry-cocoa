final class SentryWatchdogTerminationHangTracker {
    private let queue: SentryDispatchQueueWrapperProtocol
    private let tracker: SentryHangTracker
    private let timeoutInterval: TimeInterval
    private let hangStarted: () -> Void
    private let hangStopped: () -> Void

    private var callbackId: (late: UUID, finishedRunLoop: UUID)?
    private var finishedRunLoopId: UUID?
    private var currentHangId: UUID?

    init(
        queue: SentryDispatchQueueWrapperProtocol,
        hangTracker: SentryHangTracker,
        appStateManager: SentryAppStateManager,
        timeoutInterval: TimeInterval
    ) {
        self.queue = queue
        self.tracker = hangTracker
        self.timeoutInterval = timeoutInterval
        self.hangStarted = { [weak appStateManager] in
            SentrySDKLog.debug("App hang detected in watchdog termination tracking")
            appStateManager?.updateAppState { appState in
                appState.isANROngoing = true
            }
        }
        self.hangStopped = { [weak appStateManager] in
            appStateManager?.updateAppState { appState in
                appState.isANROngoing = false
            }
        }
    }

    func start() {
        queue.dispatchSyncOnMainQueue { [self] in
            let late = tracker.addLateRunLoopObserver { [weak self] id, interval in
                guard let self = self else { return }
                guard id != currentHangId, interval > timeoutInterval else {
                    return
                }

                currentHangId = id
                self.hangStarted()
            }
            let finished = tracker.addFinishedRunLoopObserver { [weak self] _ in
                self?.hangStopped()
            }
            callbackId = (late, finished)
        }
    }

    func stop() {
        queue.dispatchSyncOnMainQueue { [self] in
            guard let callbackId else {
                return
            }
            tracker.removeLateRunLoopObserver(id: callbackId.late)
            tracker.removeFinishedRunLoopObserver(id: callbackId.finishedRunLoop)
        }
    }
}
