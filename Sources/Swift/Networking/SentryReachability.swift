import Foundation

#if !os(watchOS) && !((swift(>=5.9) && os(visionOS)) && SENTRY_NO_UIKIT)
import Network

// MARK: - SentryConectivity
@objc
public enum SentryConnectivity: Int {
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
    private var pathMonitor: Any? // NWPathMonitor for iOS 12+
    private var reachabilityQueue: DispatchQueue?
    private let observersLock = NSLock()
    
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    @objc public var skipRegisteringActualCallbacks = false
    private var ignoreActualCallback = false
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
            return
        }
        
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if skipRegisteringActualCallbacks {
            SentrySDKLog.debug("Skip registering actual callbacks")
            return
        }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        
        let reachabilityQueue = DispatchQueue(label: "io.sentry.cocoa.connectivity")
        self.reachabilityQueue = reachabilityQueue
        
        if #available(iOS 12.0, macOS 10.14, tvOS 12.0, *) {
            let monitor = NWPathMonitor()
            pathMonitor = monitor
            monitor.pathUpdateHandler = pathUpdateHandler
            monitor.start(queue: reachabilityQueue)
            
            SentrySDKLog.debug("Started NWPathMonitor")
        } else {
            // For iOS 11 and earlier, simulate always being connected via WiFi
            SentrySDKLog.warning("NWPathMonitor not available. Using fallback: always connected via WiFi")
            reachabilityQueue.async { [weak self] in
                self?.connectivityCallback(.wiFi)
            }
        }
    }
    
    @objc(removeObserver:)
    public func remove(_ observer: SentryReachabilityObserver) {
        SentrySDKLog.debug("Removing observer: \(observer)")
        
        observersLock.lock()
        defer { observersLock.unlock() }
        
        SentrySDKLog.debug("Synchronized to remove observer: \(observer)")
        reachabilityObservers.remove(observer)
        
        if reachabilityObservers.count == 0 {
            stopMonitoring()
        }
    }
    
    @objc
    public func removeAllObservers() {
        SentrySDKLog.debug("Removing all observers.")
        
        observersLock.lock()
        defer { observersLock.unlock() }
        
        SentrySDKLog.debug("Synchronized to remove all observers.")
        reachabilityObservers.removeAllObjects()
        stopMonitoring()
    }
    
    private func stopMonitoring() {
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if skipRegisteringActualCallbacks {
            SentrySDKLog.debug("Skip stopping actual monitoring")
        }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        
        currentConnectivity = .none
        
        // Clean up NWPathMonitor
        if #available(iOS 12.0, macOS 10.14, tvOS 12.0, *) {
            if let monitor = pathMonitor as? NWPathMonitor {
                SentrySDKLog.debug("Stopping NWPathMonitor")
                monitor.cancel()
                pathMonitor = nil
            }
        }
        
        SentrySDKLog.debug("Cleaning up reachability queue.")
        reachabilityQueue = nil
    }
    
    @available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
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
    
    @available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
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
    
    private func connectivityShouldReportChange(_ connectivity: SentryConnectivity) -> Bool {
        if connectivity == currentConnectivity {
            SentrySDKLog.debug("No change in reachability state. ConnectivityShouldReportChange will return false for connectivity \(connectivity.toString()), currentConnectivity \(currentConnectivity.toString())")
            return false
        }
        
        currentConnectivity = connectivity
        return true
    }
    
    fileprivate func connectivityCallback(_ connectivity: SentryConnectivity) {
        observersLock.lock()
        defer { observersLock.unlock() }
        
        SentrySDKLog.debug("Entered synchronized region of SentryConnectivityCallback with connectivity: \(connectivity.toString())")
        
        guard reachabilityObservers.count > 0 else {
            SentrySDKLog.debug("No reachability observers registered. Nothing to do.")
            return
        }
        
        guard connectivityShouldReportChange(connectivity) else {
            SentrySDKLog.debug("ConnectivityShouldReportChange returned false for connectivity \(connectivity.toString()), will not report change to observers.")
            return
        }
        
        let connected = connectivity != .none
        
        SentrySDKLog.debug("Notifying observers...")
        for observer in reachabilityObservers.allObjects {
            SentrySDKLog.debug("Notifying \(observer)")
            observer.connectivityChanged(connected, typeDescription: connectivity.toString())
        }
        SentrySDKLog.debug("Finished notifying observers.")
    }
    
    deinit {
        removeAllObservers()
    }
}

// MARK: - Test utils
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
@available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
extension SentryReachability {
    @objc public func setReachabilityIgnoreActualCallback(_ value: Bool) {
        SentrySDKLog.debug("Setting ignore actual callback to \(value)")
        ignoreActualCallback = value
    }
    
    @objc public func triggerConnectivityCallback(_ connectivity: SentryConnectivity) {
        connectivityCallback(connectivity)
    }
}

@_spi(Private) @objc public class SentryReachabilityTestHelper: NSObject {
    @objc static public func stringForSentryConnectivity(_ type: SentryConnectivity) -> String {
        type.toString()
    }
}
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI

#endif // !os(watchOS) && !((swift(>=5.9) && os(visionOS)) && SENTRY_NO_UIKIT)
