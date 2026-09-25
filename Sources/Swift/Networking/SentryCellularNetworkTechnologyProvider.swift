// CoreTelephony only exists on iOS, so this whole file is gated instead of standing in a no-op
// implementation on the other platforms. SentryReachability gates its usage the same way.
#if os(iOS) && !targetEnvironment(macCatalyst)

import CoreTelephony
import Foundation

/// The generation of the cellular network technology a device currently uses for data.
enum SentryCellularNetworkTechnology: String {
    case secondGeneration = "2g"
    case thirdGeneration = "3g"
    case fourthGeneration = "4g"
    case fifthGeneration = "5g"

    /// Maps a `CTRadioAccessTechnology` constant to its generation, `nil` for unknown values.
    init?(radioAccessTechnology: String) {
        switch radioAccessTechnology {
        case CTRadioAccessTechnologyGPRS,
             CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyCDMA1x:
            self = .secondGeneration
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            self = .thirdGeneration
        case CTRadioAccessTechnologyLTE:
            self = .fourthGeneration
        case CTRadioAccessTechnologyNRNSA,
             CTRadioAccessTechnologyNR:
            self = .fifthGeneration
        default:
            SentrySDKLog.debug("Unknown radio access technology: \(radioAccessTechnology)")
            return nil
        }
    }
}

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryCellularNetworkTechnologyProviding {
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

/// Reports the cellular network technology of the data service via `CoreTelephony`.
///
/// Reading `serviceCurrentRadioAccessTechnology` needs no entitlement and no `Info.plist` entry,
/// unlike the parts of `CoreTelephony` that identify the carrier.
///
/// The value is cached and refreshed when the radio access technology changes, because reading it
/// from `CoreTelephony` communicates with a system service and must not happen while capturing an
/// event.
struct SentryCellularNetworkTechnologyProvider {

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
    /// can be the main thread, so the work is moved to a queue of our own.
    private let dispatchQueue: SentryDispatchQueueWrapper

    init(
        notificationCenter: NotificationCenter = .default,
        dispatchQueue: SentryDispatchQueueWrapper = SentryDispatchQueueWrapper(name: "io.sentry.cocoa.cellular-network-technology")
    ) {
        self.notificationCenter = notificationCenter
        self.dispatchQueue = dispatchQueue
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
        // Capturing the mutex instead of self keeps this a value type: the storage is shared, so
        // the observer sees the same state the provider does.
        let state = self.state
        let dispatchQueue = self.dispatchQueue
        let observerToken = notificationCenter.addObserver(
            forName: .CTServiceRadioAccessTechnologyDidChange,
            object: nil,
            queue: nil
        ) { _ in
            // The notification arrives on the posting thread, so nothing but the hand-off happens
            // there. Reading the technology talks to a system service.
            dispatchQueue.dispatchAsync {
                Self.refreshTechnology(in: state)
            }
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

    private static func refreshTechnology(in state: SentryMutex<State>) {
        guard let networkInfo = state.withLock({ $0.networkInfo }) else {
            SentrySDKLog.debug("Not monitoring the cellular network technology. Nothing to refresh.")
            return
        }
        // Reading the radio access technology talks to a system service, so it happens outside the
        // lock that capturing an event uses.
        let technology = technology(from: networkInfo)
        let didRefresh = state.withLock { state -> Bool in
            guard state.isMonitoring else {
                return false
            }
            state.technology = technology
            return true
        }
        guard didRefresh else {
            SentrySDKLog.debug("Monitoring stopped while refreshing the cellular network technology.")
            return
        }
        SentrySDKLog.debug("Refreshed the cellular network technology: \(technology?.rawValue ?? "unknown")")
    }

    private static func technology(from networkInfo: CTTelephonyNetworkInfo) -> SentryCellularNetworkTechnology? {
        guard let technologies = networkInfo.serviceCurrentRadioAccessTechnology, !technologies.isEmpty else {
            SentrySDKLog.debug("No radio access technology reported. The device may have no cellular service.")
            return nil
        }

        // Devices with multiple SIMs report one radio access technology per service. Only the
        // service used for data describes the connection of the app, so prefer it.
        if let dataServiceIdentifier = networkInfo.dataServiceIdentifier,
           let radioAccessTechnology = technologies[dataServiceIdentifier],
           let technology = SentryCellularNetworkTechnology(radioAccessTechnology: radioAccessTechnology) {
            return technology
        }

        // Sorting the identifiers keeps the reported value stable when the data service is unknown.
        for serviceIdentifier in technologies.keys.sorted() {
            if let radioAccessTechnology = technologies[serviceIdentifier],
               let technology = SentryCellularNetworkTechnology(radioAccessTechnology: radioAccessTechnology) {
                return technology
            }
        }
        return nil
    }

}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
