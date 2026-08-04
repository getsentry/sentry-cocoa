/// Routes process-lifetime swizzles to the tracker owned by the current SDK lifecycle.
/// A new tracker is registered when restarting the SDK with a new dependency container.
final class SentryNetworkTrackerProxy {
    // The proxy must not extend the tracker's integration and dependency-container lifetime.
    private final class WeakBox {
        weak var value: SentryNetworkTrackerProtocol?

        init(_ value: SentryNetworkTrackerProtocol) {
            self.value = value
        }
    }

    static let shared = SentryNetworkTrackerProxy()

    private let weakTargetMutex = SentryMutex<WeakBox?>(nil)

    var target: SentryNetworkTrackerProtocol? {
        weakTargetMutex.withLock { $0?.value }
    }

    func setTarget(_ target: SentryNetworkTrackerProtocol) {
        let reference = WeakBox(target)
        weakTargetMutex.withLock { $0 = reference }
    }

    func removeTarget(_ target: SentryNetworkTrackerProtocol) {
        weakTargetMutex.withLock {
            // An older integration must not remove a newer integration's tracker.
            guard $0?.value === target else {
                return
            }
            $0 = nil
        }
    }
}
