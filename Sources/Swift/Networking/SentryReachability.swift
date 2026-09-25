// swiftlint:disable missing_docs
import Foundation
import Network

// MARK: - SentryConnectivity
enum SentryConnectivity: Int {
    case cellular
    case wiFi
    case ethernet
    case none

    func toString() -> String {
        switch self {
        case .cellular:
            return "cellular"
        case .wiFi:
            return "wifi"
        case .ethernet:
            return "ethernet"
        case .none:
            return "none"
        }
    }
}

@_spi(Private) @objc
public protocol SentryReachabilityObserver: NSObjectProtocol {
    @objc func connectivityChanged(_ connected: Bool, typeDescription: String)
}

// MARK: - SentryReachability
@_spi(Private) @objc
public class SentryReachability: NSObject {
    private var reachabilityObservers = NSHashTable<SentryReachabilityObserver>.weakObjects()
    /// The connectivity of the last known network path, or `nil` while no path has been reported yet.
    private var currentConnectivity: SentryConnectivity?
    private var pathMonitor: NWPathMonitor?
#if os(iOS) && !targetEnvironment(macCatalyst)
    private let cellularNetworkTechnologyProvider: SentryCellularNetworkTechnologyProviding

    init(cellularNetworkTechnologyProvider: SentryCellularNetworkTechnologyProviding = SentryCellularNetworkTechnologyProvider()) {
        self.cellularNetworkTechnologyProvider = cellularNetworkTechnologyProvider
        super.init()
    }
#endif // os(iOS) && !targetEnvironment(macCatalyst)
    private let reachabilityQueue: DispatchQueue = DispatchQueue(label: "io.sentry.cocoa.connectivity", qos: .background, attributes: [])
    private let observersLock = NSRecursiveLock()
    
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    @objc public var skipRegisteringActualCallbacks = false
    private var ignoreActualCallback = false
    
    public var pathMonitorIsNil: Bool {
        return pathMonitor == nil
    }

    var currentPathMonitor: NWPathMonitor? {
        observersLock.synchronized { pathMonitor }
    }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    
    @objc(addObserver:)
    public func add(_ observer: SentryReachabilityObserver) {
        SentrySDKLog.debug("Adding observer: \(observer)")
        
        observersLock.lock()
        defer { observersLock.unlock() }
        
        SentrySDKLog.debug("Synchronized to add observer: \(observer)")
        
        if reachabilityObservers.contains(observer) {
            SentrySDKLog.debug("Observer already added. Doing nothing.")
            return
        }
        
        reachabilityObservers.add(observer)
        
        if reachabilityObservers.count > 1 {
            SentrySDKLog.debug("More than one observer added. Doing nothing.")
            return
        }
        
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if skipRegisteringActualCallbacks {
            SentrySDKLog.debug("Skip registering actual callbacks")
            return
        }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        
        self.currentConnectivity = nil
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak self, weak pathMonitor] path in
            guard let self, let pathMonitor, self.isCurrentPathMonitor(pathMonitor) else {
                return
            }
            self.pathUpdateHandler(path)
        }
        self.pathMonitor = pathMonitor
        pathMonitor.start(queue: self.reachabilityQueue)

#if os(iOS) && !targetEnvironment(macCatalyst)
        // Starting the provider talks to a system service, which must not block the thread calling
        // into the SDK, so it runs on the same queue as the path monitor. The provider is never
        // nil; it is copied into a local only to keep self out of the escaping block.
        let cellularNetworkTechnologyProvider = self.cellularNetworkTechnologyProvider
        reachabilityQueue.async {
            cellularNetworkTechnologyProvider.startMonitoring()
        }
#endif // os(iOS) && !targetEnvironment(macCatalyst)
    }

    /// Starting and stopping the cellular network technology monitoring both go through the serial
    /// reachability queue, so an observer that is removed before the queued start ran still ends up
    /// with the monitoring stopped instead of leaking it for the lifetime of this instance.
    private func stopMonitoringCellularNetworkTechnology() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        let cellularNetworkTechnologyProvider = self.cellularNetworkTechnologyProvider
        reachabilityQueue.async {
            cellularNetworkTechnologyProvider.stopMonitoring()
        }
#endif // os(iOS) && !targetEnvironment(macCatalyst)
    }
    
    @objc(removeObserver:)
    public func remove(_ observer: SentryReachabilityObserver) {
        SentrySDKLog.debug("Removing observer: \(observer)")
        
        observersLock.synchronized {
            SentrySDKLog.debug("Synchronized to remove observer: \(observer)")
            reachabilityObservers.remove(observer)
            
            if reachabilityObservers.count == 0 {
                stopMonitoring()
            }
        }
    }
    
    @objc
    public func removeAllObservers() {
        SentrySDKLog.debug("Removing all observers.")
        
        observersLock.synchronized {
            SentrySDKLog.debug("Synchronized to remove all observers.")
            reachabilityObservers.removeAllObjects()
            stopMonitoring()
        }
    }
    
    private func stopMonitoring() {
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if skipRegisteringActualCallbacks {
            SentrySDKLog.debug("Skip stopping actual monitoring")
        }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        
        // Clean up NWPathMonitor
        if let monitor = pathMonitor {
            SentrySDKLog.debug("Stopping NWPathMonitor")
            monitor.cancel()
            pathMonitor = nil
        }
        currentConnectivity = nil
        stopMonitoringCellularNetworkTechnology()
    }

    /// The last known network path, and `nil` while the SDK isn't monitoring connectivity.
    ///
    /// `type` is the connection type, for example `wifi`, `ethernet` or `cellular`. `effectiveType`
    /// is the generation of the cellular network technology, for example `5g`, and is `nil` unless
    /// the path is cellular with a known technology.
    ///
    /// Both are read under one lock, so they always describe the same path instead of straddling a
    /// connectivity change.
    var currentConnection: (type: String, effectiveType: String?)? {
        observersLock.synchronized {
            guard let connectivity = currentConnectivity else {
                return nil
            }
            var effectiveType: String?
#if os(iOS) && !targetEnvironment(macCatalyst)
            if connectivity == .cellular {
                effectiveType = cellularNetworkTechnologyProvider.currentTechnology?.rawValue
            }
#endif // os(iOS) && !targetEnvironment(macCatalyst)
            return (connectivity.toString(), effectiveType)
        }
    }
    
    func isCurrentPathMonitor(_ pathMonitor: NWPathMonitor) -> Bool {
        observersLock.synchronized {
            self.pathMonitor === pathMonitor
        }
    }

    private func pathUpdateHandler(_ path: NWPath) {
        SentrySDKLog.debug("SentryPathUpdateHandler called with path status: \(path.status)")
        
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if ignoreActualCallback {
            SentrySDKLog.debug("Ignoring actual callback.")
            return
        }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        
        let connectivity = connectivityFromPath(path)
        connectivityCallback(connectivity)
    }
    
    private func connectivityFromPath(_ path: NWPath) -> SentryConnectivity {
        guard path.status == .satisfied else {
            return .none
        }
        
#if canImport(UIKit)
        if path.usesInterfaceType(.cellular) {
            return .cellular
        }
#endif // canImport(UIKit)
        if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        // Paths that neither use cellular nor wired ethernet, such as VPN interfaces, have
        // historically been reported as Wi-Fi, which is the most likely interface type.
        return .wiFi
    }
    
    fileprivate func connectivityCallback(_ connectivity: SentryConnectivity) {
        // DEADLOCK PREVENTION: Copy observers while holding the lock, then notify outside the lock.
        //
        // A deadlock can occur when two threads acquire locks in opposite orders:
        //   Thread A: instanceLock -> observersLock (e.g., test cleanup calls SentryDependencyContainer.reset()
        //             which eventually calls removeAllObservers())
        //   Thread B: observersLock -> instanceLock (e.g., this callback notifies an observer that creates
        //             a breadcrumb, which calls SentryDependencyContainer.sharedInstance)
        //
        // By copying the observers list and releasing observersLock before notifying, we ensure this method
        // never holds observersLock while calling observer code that might acquire other locks.
        // Reading the observers and swapping the connectivity in one critical section keeps a
        // stopMonitoring that lands in between from being undone by the write.
        let (observersToNotify, previousConnectivity) = observersLock.synchronized {
            () -> ([SentryReachabilityObserver], SentryConnectivity?) in
            let observers = reachabilityObservers.allObjects
            guard !observers.isEmpty else {
                // Observers are held weakly, so the last one can disappear without remove(_:).
                // Forget the connectivity so currentConnection stops reporting the network from
                // when observers still existed. The path monitor is deliberately left alone: this
                // runs on its own queue from its update handler, and cancelling it from there
                // wedges the queue.
                currentConnectivity = nil
                return ([], nil)
            }
            let previousConnectivity = currentConnectivity
            currentConnectivity = connectivity
            return (observers, previousConnectivity)
        }
        
        SentrySDKLog.debug("Entered synchronized region of SentryConnectivityCallback with connectivity: \(connectivity.toString())")
        
        guard observersToNotify.count > 0 else {
            SentrySDKLog.debug("No reachability observers registered. Nothing to do.")
            return
        }
        
        guard connectivityShouldReportChange(previousConnectivity ?? .none, connectivity) else {
            return
        }
        
        let connected = connectivity != .none
        let typeDescription = connectivity.toString()
        
        // Notify observers outside the lock to avoid deadlock.
        // Observers may call back into SDK code that needs other locks (e.g., SentryDependencyContainer.instanceLock).
        SentrySDKLog.debug("Notifying observers with connected: \(connected), connectivity: \(typeDescription)")
        for observer in observersToNotify {
            SentrySDKLog.debug("Notifying \(observer)")
            observer.connectivityChanged(connected, typeDescription: typeDescription)
        }
        SentrySDKLog.debug("Finished notifying observers.")
    }

    private func connectivityShouldReportChange(_ previousConnectivity: SentryConnectivity, _ newConnectivity: SentryConnectivity) -> Bool {
        if previousConnectivity == newConnectivity {
            SentrySDKLog.debug("No change in reachability state. ConnectivityShouldReportChange will return false for connectivity \(previousConnectivity.toString()), newConnectivity \(newConnectivity.toString())")
            return false
        }
        
        return true
    }
    
    deinit {
        removeAllObservers()
    }
}

// MARK: - Test utils
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
extension SentryReachability {
    func setReachabilityIgnoreActualCallback(_ value: Bool) {
        SentrySDKLog.debug("Setting ignore actual callback to \(value)")
        ignoreActualCallback = value
    }

    func triggerConnectivityCallback(_ connectivity: SentryConnectivity) {
        connectivityCallback(connectivity)
    }
}

class SentryReachabilityTestHelper: NSObject {
    static func stringForSentryConnectivity(_ type: SentryConnectivity) -> String {
        type.toString()
    }
}
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
// swiftlint:enable missing_docs
