#if !os(watchOS)

import SentryTestUtils

class TestSentryReachability: SentryReachability {
    
    private var observers: NSHashTable<SentryReachabilityObserver> = NSHashTable.weakObjects()

    override func add(_ observer: SentryReachabilityObserver) {
        observers.add(observer)
    }

    func setReachabilityState(state: String) {
        for observer in observers.allObjects {
            observer.connectivityChanged(state != SentryConnectivityNone, typeDescription: state)
        }
        
    }

    func triggerNetworkReachable() {
        for observer in observers.allObjects {
            observer.connectivityChanged(true, typeDescription: SentryConnectivityWiFi)
        }
    }
    
    var stopMonitoringInvocations = Invocations<Void>()
    override func remove(_ observer: SentryReachabilityObserver) {
        stopMonitoringInvocations.record(Void())
    }
}

#endif // !os(watchOS)
