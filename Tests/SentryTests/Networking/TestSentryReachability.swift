#if !os(watchOS)

import SentryTestUtils

class TestSentryReachability: SentryReachability {
    var block: SentryConnectivityChangeBlock?

    override func add(_ observer: SentryReachabilityObserver, withCallback block: @escaping SentryConnectivityChangeBlock) {
        self.block = block
    }

    func setReachabilityState(state: String) {
        block?(state != SentryConnectivityNone, state)
    }

    func triggerNetworkReachable() {
        block?(true, SentryConnectivityWiFi)
    }
    
    var stopMonitoringInvocations = Invocations<Void>()
    override func remove(_ observer: SentryReachabilityObserver) {
        stopMonitoringInvocations.record(Void())
    }
}

#endif // !os(watchOS)
