import Foundation

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreTelephony
#endif // os(iOS) && !targetEnvironment(macCatalyst)

/// The generation of the cellular network technology a device currently uses for data.
enum SentryCellularNetworkTechnology: String {
    case secondGeneration = "2g"
    case thirdGeneration = "3g"
    case fourthGeneration = "4g"
    case fifthGeneration = "5g"
}

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryCellularNetworkTechnologyProviding: AnyObject {
    /// The technology of the cellular network currently used for data, or `nil` when it is unknown,
    /// not being monitored, or not exposed by the platform.
    var currentTechnology: SentryCellularNetworkTechnology? { get }

    func startMonitoring()
    func stopMonitoring()
}

extension SentryCellularNetworkTechnologyProvider: SentryCellularNetworkTechnologyProviding {}
#else
typealias SentryCellularNetworkTechnologyProviding = SentryCellularNetworkTechnologyProvider
#endif // SENTRY_TEST || SENTRY_TEST_CI || DEBUG

#if os(iOS) && !targetEnvironment(macCatalyst)

/// Reports the cellular network technology of the data service via `CoreTelephony`.
///
/// The value is cached and refreshed when the radio access technology changes, because reading it
/// from `CoreTelephony` communicates with a system service and must not happen while capturing an
/// event.
final class SentryCellularNetworkTechnologyProvider {

    private struct State {
        /// Set before `CoreTelephony` is set up, so concurrent callers can't both start monitoring
        /// and a `stopMonitoring` racing the setup isn't undone by it.
        var isMonitoring = false
        var networkInfo: CTTelephonyNetworkInfo?
        var technology: SentryCellularNetworkTechnology?
        var observerToken: NSObjectProtocol?
    }

    private let state = SentryMutex(State())
    private let notificationCenter: NotificationCenter

    /// Radio access technology notifications are delivered on whichever thread posts them, which
    /// can be the main thread, so they are handed to a queue of our own instead.
    let notificationQueue: OperationQueue

    /// `OperationQueue.underlyingQueue` is `unowned(unsafe)`, so the dispatch queue has to be kept
    /// alive here.
    private let notificationDispatchQueue: DispatchQueue

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        let notificationDispatchQueue = DispatchQueue(
            label: "io.sentry.cocoa.cellular-network-technology",
            qos: .utility
        )
        let notificationQueue = OperationQueue()
        notificationQueue.name = "io.sentry.cocoa.cellular-network-technology"
        notificationQueue.maxConcurrentOperationCount = 1
        notificationQueue.underlyingQueue = notificationDispatchQueue
        self.notificationDispatchQueue = notificationDispatchQueue
        self.notificationQueue = notificationQueue
    }

    var currentTechnology: SentryCellularNetworkTechnology? {
        state.withLock { $0.technology }
    }

    /// Starts monitoring the radio access technology.
    ///
    /// - Warning: Instantiating `CTTelephonyNetworkInfo` talks to a system service, so callers must
    ///            not call this from the main thread.
    func startMonitoring() {
        let didClaimMonitoring = state.withLock { state -> Bool in
            guard !state.isMonitoring else { return false }
            state.isMonitoring = true
            return true
        }
        guard didClaimMonitoring else {
            SentrySDKLog.debug("Already monitoring the cellular network technology. Doing nothing.")
            return
        }

        // Creating the network info and reading the radio access technology call into a system
        // service. Capturing an event reads the cached technology under the same lock, so this
        // must not happen while holding it.
        let networkInfo = CTTelephonyNetworkInfo()
        let technology = Self.technology(from: networkInfo)
        let observerToken = notificationCenter.addObserver(
            forName: .CTServiceRadioAccessTechnologyDidChange,
            object: nil,
            queue: notificationQueue
        ) { [weak self] _ in
            self?.refreshTechnology()
        }

        let didStoreMonitoring = state.withLock { state -> Bool in
            // stopMonitoring can run while CoreTelephony is being set up above.
            guard state.isMonitoring else { return false }
            state.networkInfo = networkInfo
            state.technology = technology
            state.observerToken = observerToken
            return true
        }
        guard didStoreMonitoring else {
            notificationCenter.removeObserver(observerToken)
            SentrySDKLog.debug("Monitoring the cellular network technology stopped while starting.")
            return
        }
        SentrySDKLog.debug("Started monitoring the cellular network technology: \(technology?.rawValue ?? "unknown")")
    }

    func stopMonitoring() {
        let observerToken = state.withLock { state -> NSObjectProtocol? in
            state.isMonitoring = false
            let observerToken = state.observerToken
            state.observerToken = nil
            state.networkInfo = nil
            state.technology = nil
            return observerToken
        }
        if let observerToken {
            notificationCenter.removeObserver(observerToken)
        }
        SentrySDKLog.debug("Stopped monitoring the cellular network technology.")
    }

    private func refreshTechnology() {
        guard let networkInfo = state.withLock({ $0.networkInfo }) else {
            return
        }
        // Reading the radio access technology talks to a system service, so it happens outside the
        // lock that capturing an event uses.
        let technology = Self.technology(from: networkInfo)
        state.withLock { state in
            guard state.isMonitoring else {
                return
            }
            state.technology = technology
        }
    }

    private static func technology(from networkInfo: CTTelephonyNetworkInfo) -> SentryCellularNetworkTechnology? {
        guard let technologies = networkInfo.serviceCurrentRadioAccessTechnology, !technologies.isEmpty else {
            return nil
        }

        // Devices with multiple SIMs report one radio access technology per service. Only the
        // service used for data describes the connection of the app, so prefer it.
        if let dataServiceIdentifier = networkInfo.dataServiceIdentifier,
           let radioAccessTechnology = technologies[dataServiceIdentifier],
           let technology = technology(forRadioAccessTechnology: radioAccessTechnology) {
            return technology
        }

        // Sorting the identifiers keeps the reported value stable when the data service is unknown.
        for serviceIdentifier in technologies.keys.sorted() {
            if let radioAccessTechnology = technologies[serviceIdentifier],
               let technology = technology(forRadioAccessTechnology: radioAccessTechnology) {
                return technology
            }
        }
        return nil
    }

    static func technology(forRadioAccessTechnology radioAccessTechnology: String) -> SentryCellularNetworkTechnology? {
        switch radioAccessTechnology {
        case CTRadioAccessTechnologyGPRS,
             CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyCDMA1x:
            return .secondGeneration
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return .thirdGeneration
        case CTRadioAccessTechnologyLTE:
            return .fourthGeneration
        case CTRadioAccessTechnologyNRNSA,
             CTRadioAccessTechnologyNR:
            return .fifthGeneration
        default:
            SentrySDKLog.debug("Unknown radio access technology: \(radioAccessTechnology)")
            return nil
        }
    }
}

#else

/// `CoreTelephony` is only available on iOS, so the cellular network technology can't be
/// determined on the other platforms.
final class SentryCellularNetworkTechnologyProvider {
    var currentTechnology: SentryCellularNetworkTechnology? { nil }
    func startMonitoring() {}
    func stopMonitoring() {}
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
