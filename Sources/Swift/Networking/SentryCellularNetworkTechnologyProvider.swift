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
        var networkInfo: CTTelephonyNetworkInfo?
        var technology: SentryCellularNetworkTechnology?
        var observerToken: NSObjectProtocol?
    }

    private let state = SentryMutex(State())
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    var currentTechnology: SentryCellularNetworkTechnology? {
        state.withLock { $0.technology }
    }

    /// Starts monitoring the radio access technology.
    ///
    /// - Warning: Instantiating `CTTelephonyNetworkInfo` talks to a system service, so callers must
    ///            not call this from the main thread.
    func startMonitoring() {
        // Registering the observer in the same critical section as creating the network info keeps
        // repeated calls from piling up observers and stopMonitoring from leaking one.
        let technology: SentryCellularNetworkTechnology?? = state.withLock { state in
            guard state.networkInfo == nil else { return nil }
            let networkInfo = CTTelephonyNetworkInfo()
            state.networkInfo = networkInfo
            state.technology = Self.technology(from: networkInfo)
            state.observerToken = notificationCenter.addObserver(
                forName: .CTServiceRadioAccessTechnologyDidChange,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.refreshTechnology()
            }
            return state.technology
        }

        guard let technology else {
            SentrySDKLog.debug("Already monitoring the cellular network technology. Doing nothing.")
            return
        }
        SentrySDKLog.debug("Started monitoring the cellular network technology: \(technology?.rawValue ?? "unknown")")
    }

    func stopMonitoring() {
        let token = state.withLock { state -> NSObjectProtocol? in
            let token = state.observerToken
            state.observerToken = nil
            state.networkInfo = nil
            state.technology = nil
            return token
        }
        if let token {
            notificationCenter.removeObserver(token)
        }
        SentrySDKLog.debug("Stopped monitoring the cellular network technology.")
    }

    private func refreshTechnology() {
        state.withLock { state in
            guard let networkInfo = state.networkInfo else { return }
            state.technology = Self.technology(from: networkInfo)
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
