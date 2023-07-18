#if !os(watchOS)

import SentryTestUtils

class TestSentryReachability: SentryReachability {
    var block: SentryConnectivityChangeBlock?

    override func monitorURL(_ URL: URL, usingCallback block: @escaping SentryConnectivityChangeBlock) {
        self.block = block
    }

    func triggerNetworkReachable() {
        block?(true, "wifi")
    }
    
    var stopMonitoringInvocations = Invocations<Void>()
    override func stopMonitoring() {
        stopMonitoringInvocations.record(Void())
    }
}

#endif // !os(watchOS)
