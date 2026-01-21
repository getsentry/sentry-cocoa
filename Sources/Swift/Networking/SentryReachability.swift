// swiftlint:disable missing_docs
import Foundation
import Network

// MARK: - SentryConnectivity
enum SentryConnectivity: Int {
    case cellular
    case wiFi
    case none

    func toString() -> String {
        switch self {
        case .cellular:
            return "cellular"
        case .wiFi:
            return "wifi"
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
    private var currentConnectivity: SentryConnectivity = .none
    private var pathMonitor: NWPathMonitor?
    private let reachabilityQueue: DispatchQueue = DispatchQueue(label: "io.sentry.cocoa.connectivity", qos: .background, attributes: [])
    private let observersLock = NSRecursiveLock()
    
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    @objc public var skipRegisteringActualCallbacks = false
    private var ignoreActualCallback = false
    
    public var pathMonitorIsNil: Bool {
        return pathMonitor == nil
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
        
        self.pathMonitor = NWPathMonitor()
        self.pathMonitor?.pathUpdateHandler = self.pathUpdateHandler
        self.pathMonitor?.start(queue: self.reachabilityQueue)
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
        
        currentConnectivity = .none
        
        // Clean up NWPathMonitor
        if let monitor = pathMonitor {
            SentrySDKLog.debug("Stopping NWPathMonitor")
            monitor.cancel()
            pathMonitor = nil
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
        } else {
            return .wiFi
        }
#else
        return .wiFi
#endif // canImport(UIKit)
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
        let observersToNotify = observersLock.synchronized {
            reachabilityObservers.allObjects
        }
        
        SentrySDKLog.debug("Entered synchronized region of SentryConnectivityCallback with connectivity: \(connectivity.toString())")
        
        guard observersToNotify.count > 0 else {
            SentrySDKLog.debug("No reachability observers registered. Nothing to do.")
            return
        }
        
        let previousConnectivity = currentConnectivity
        currentConnectivity = connectivity
        guard connectivityShouldReportChange(previousConnectivity, currentConnectivity) else {
            return
        }
        
        let connected = connectivity != .none
        
        // Notify observers outside the lock to avoid deadlock.
        // Observers may call back into SDK code that needs other locks (e.g., SentryDependencyContainer.instanceLock).
        SentrySDKLog.debug("Notifying observers with connected: \(connected), connectivity: \(connectivity.toString())")
        for observer in observersToNotify {
            SentrySDKLog.debug("Notifying \(observer)")
            observer.connectivityChanged(connected, typeDescription: connectivity.toString())
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
