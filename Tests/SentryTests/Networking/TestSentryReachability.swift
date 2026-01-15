// swiftlint:disable missing_docs
#if !os(watchOS) && !(os(visionOS) && !canImport(UIKit))

@_spi(Private) @testable import Sentry
import SentryTestUtils

@_spi(Private) public class TestSentryReachability: SentryReachability {
    
    private var observers: NSHashTable<SentryReachabilityObserver> = NSHashTable.weakObjects()

    public override func add(_ observer: SentryReachabilityObserver) {
        observers.add(observer)
    }

    func setReachabilityState(state: SentryConnectivity) {
        for observer in observers.allObjects {
            observer.connectivityChanged(state != .none, typeDescription: state.toString())
        }
        
    }

    func triggerNetworkReachable() {
        for observer in observers.allObjects {
            observer.connectivityChanged(true, typeDescription: SentryConnectivity.wiFi.toString())
        }
    }
    
    var stopMonitoringInvocations = Invocations<Void>()
    public override func remove(_ observer: SentryReachabilityObserver) {
        stopMonitoringInvocations.record(Void())
    }
}

#endif // !os(watchOS) && !(os(visionOS) && !canImport(UIKit))
// swiftlint:enable missing_docs
