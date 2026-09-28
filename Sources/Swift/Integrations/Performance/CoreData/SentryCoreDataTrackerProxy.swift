/// Routes process-lifetime swizzles to the tracker owned by the current SDK lifecycle.
final class SentryCoreDataTrackerProxy {
    private final class WeakBox {
        weak var value: SentryCoreDataTrackerProtocol?

        init(_ value: SentryCoreDataTrackerProtocol) {
            self.value = value
        }
    }

    static let shared = SentryCoreDataTrackerProxy()

    private let weakTargetMutex = SentryMutex<WeakBox?>(nil)

    var target: SentryCoreDataTrackerProtocol? {
        weakTargetMutex.withLock { $0?.value }
    }

    func setTarget(_ target: SentryCoreDataTrackerProtocol) {
        let reference = WeakBox(target)
        weakTargetMutex.withLock { $0 = reference }
    }

    func removeTarget(_ target: SentryCoreDataTrackerProtocol) {
        weakTargetMutex.withLock {
            // An older integration must not remove a newer integration's tracker.
            guard $0?.value === target else {
                return
            }
            $0 = nil
        }
    }
}
