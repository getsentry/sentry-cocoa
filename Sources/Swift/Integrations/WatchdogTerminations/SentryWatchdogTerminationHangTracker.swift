#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryWatchdogTerminationHangTracker {
    private struct CallbackIds {
        let late: UUID
        let finishedRunLoop: UUID
    }

    private let queue: SentryDispatchQueueWrapperProtocol
    private let tracker: SentryHangTracker
    private let timeoutInterval: TimeInterval
    private let hangStarted: () -> Void
    private let hangStopped: () -> Void

    private var callbackId: CallbackIds?
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
            SentrySDKLog.debug("App hang started in watchdog termination hang tracker")
            appStateManager?.updateAppState { appState in
                appState.isANROngoing = true
            }
        }
        self.hangStopped = { [weak appStateManager] in
            SentrySDKLog.debug("App hang stopped in watchdog termination hang tracker")
            appStateManager?.updateAppState { appState in
                appState.isANROngoing = false
            }
        }
    }

    func start() {
        SentrySDKLog.debug("Starting watchdog termination hang tracker")
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
                guard let self = self else { return }
                // Only call hangStopped when a hang was actually active; otherwise we'd trigger
                // disk I/O (updateAppState) 60-120 times per second on every run loop iteration.
                if self.currentHangId != nil {
                    self.currentHangId = nil
                    self.hangStopped()
                }
            }
            callbackId = CallbackIds(late: late, finishedRunLoop: finished)
        }
    }

    func stop() {
        SentrySDKLog.debug("Stopping watchdog termination hang tracker")
        queue.dispatchSyncOnMainQueue { [self] in
            guard let callbackId else {
                return
            }
            tracker.removeLateRunLoopObserver(id: callbackId.late)
            tracker.removeFinishedRunLoopObserver(id: callbackId.finishedRunLoop)
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
