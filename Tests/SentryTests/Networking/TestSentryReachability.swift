#if !os(watchOS)

import SentryTestUtils

class TestSentryReachability: SentryReachability {
    var block: SentryConnectivityChangeBlock?

    override func monitorURL(_ URL: URL, usingCallback block: @escaping SentryConnectivityChangeBlock) {
        self.block = block
    }

    func setReachabilityState(state: String) {
        block?(state != SentryConnectivityNone, state)
    }

    func triggerNetworkReachable() {
        block?(true, SentryConnectivityWiFi)
    }
    
    var stopMonitoringInvocations = Invocations<Void>()
    override func stopMonitoring() {
        stopMonitoringInvocations.record(Void())
    }
}

#endif // !os(watchOS)
