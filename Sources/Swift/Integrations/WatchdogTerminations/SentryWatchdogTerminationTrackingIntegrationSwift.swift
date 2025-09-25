@_spi(Private) @objc public final class SentryWatchdogTerminationTrackingIntegrationSwift: NSObject {

    private let tracker: HangTracker
    private let timeoutInterval: TimeInterval
    private let hangStarted: () -> Void
    private let hangStopped: () -> Void
    
    private var callbackId: (late: UUID, finishedRunLoop: UUID)?
    private var finishedRunLoopId: UUID?
    private var currentHangId: UUID?
    
    @objc public convenience init(hangTrackerBridge: SentryHangTrackerObjcBridge, timeoutInterval: TimeInterval, hangStarted: @escaping () -> Void, hangStopped: @escaping () -> Void) {
        self.init(hangTracker: hangTrackerBridge.tracker, timeoutInterval: timeoutInterval, hangStarted: hangStarted, hangStopped: hangStopped)
    }

     init(hangTracker: HangTracker, timeoutInterval: TimeInterval, hangStarted: @escaping () -> Void, hangStopped: @escaping () -> Void) {
         self.tracker = hangTracker
        self.timeoutInterval = timeoutInterval
        self.hangStarted = hangStarted
        self.hangStopped = hangStopped
    }
    
    @objc public func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        
        let late = tracker.addLateRunLoopObserver { [weak self] id, interval in
            guard let self, id != currentHangId, interval > timeoutInterval else {
                return
            }

            currentHangId = id
            hangStarted()
        }
        
        let finished = tracker.addFinishedRunLoopObserver { [weak self] _ in
            self?.hangStopped()
        }
        callbackId = (late, finished)
    }
    
    @objc public func stop() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let callbackId else {
            return
        }
        tracker.removeLateRunLoopObserver(id: callbackId.late)
        tracker.removeFinishedRunLoopObserver(id: callbackId.finishedRunLoop)
    }
}
