// swiftlint:disable missing_docs
internal import _SentryPrivate

@_spi(Private) @objc public final class SentryExtraContextProvider: NSObject {
    
    private static let kSentryProcessInfoThermalStateNominal = "nominal"
    private static let kSentryProcessInfoThermalStateFair = "fair"
    private static let kSentryProcessInfoThermalStateSerious = "serious"
    private static let kSentryProcessInfoThermalStateCritical = "critical"
    
    private let memoryMetricsProvider: SentryMemoryMetricsProvider
    private let processInfoWrapper: SentryProcessInfoSource
    private let reachability: SentryReachability
    
    #if (os(iOS)) && !SENTRY_NO_UI_FRAMEWORK
    private let deviceWrapper: SentryUIDeviceWrapper
    #if !targetEnvironment(macCatalyst)
    private let hingeObserver: SentryHingeObserving

    init(memoryMetricsProvider: SentryMemoryMetricsProvider, processInfoWrapper: SentryProcessInfoSource, deviceWrapper: SentryUIDeviceWrapper, hingeObserver: SentryHingeObserving, reachability: SentryReachability) {
        self.memoryMetricsProvider = memoryMetricsProvider
        self.processInfoWrapper = processInfoWrapper
        self.deviceWrapper = deviceWrapper
        self.hingeObserver = hingeObserver
        self.reachability = reachability
    }
    #else
    init(memoryMetricsProvider: SentryMemoryMetricsProvider, processInfoWrapper: SentryProcessInfoSource, deviceWrapper: SentryUIDeviceWrapper, reachability: SentryReachability) {
        self.memoryMetricsProvider = memoryMetricsProvider
        self.processInfoWrapper = processInfoWrapper
        self.deviceWrapper = deviceWrapper
        self.reachability = reachability
    }
    #endif // !targetEnvironment(macCatalyst)
    #else
    init(memoryMetricsProvider: SentryMemoryMetricsProvider, processInfoWrapper: SentryProcessInfoSource, reachability: SentryReachability) {
        self.memoryMetricsProvider = memoryMetricsProvider
        self.processInfoWrapper = processInfoWrapper
        self.reachability = reachability
    }
    #endif
    
    @objc public func getExtraContext() -> [String: Any] {
        [
            "device": getExtraDeviceContext(),
            "app": getExtraAppContext()
        ]
    }
    
    private func getExtraDeviceContext() -> [String: Any] {
        var extraDeviceContext: [String: Any] = [
            SentryDeviceContextFreeMemoryKey: NSNumber(value: memoryMetricsProvider.freeMemorySize),
            "processor_count": NSNumber(value: processInfoWrapper.processorCount)
        ]

        let thermalState = processInfoWrapper.thermalState
        switch thermalState {
        case .nominal:
            extraDeviceContext["thermal_state"] = Self.kSentryProcessInfoThermalStateNominal
        case .fair:
            extraDeviceContext["thermal_state"] = Self.kSentryProcessInfoThermalStateFair
        case .serious:
            extraDeviceContext["thermal_state"] = Self.kSentryProcessInfoThermalStateSerious
        case .critical:
            extraDeviceContext["thermal_state"] = Self.kSentryProcessInfoThermalStateCritical
        default:
            SentrySDKLog.warning("Unexpected thermal state enum value: \(thermalState)")
        }

        extraDeviceContext["low_power_mode"] = NSNumber(value: processInfoWrapper.isLowPowerModeEnabled)

        // The connection type is only known while the SDK monitors connectivity, which it does as
        // long as it has a transport. `connection_type` is the device context alias of
        // `network.connection.type`, so `connection_effective_type` mirrors
        // `network.connection.effective_type` the same way.
        // https://getsentry.github.io/sentry-conventions/attributes/network/
        if let connection = reachability.currentConnection {
            extraDeviceContext["connection_type"] = connection.type
            if let effectiveType = connection.effectiveType {
                extraDeviceContext["connection_effective_type"] = effectiveType
            }
        }
        
        #if (os(iOS)) && !SENTRY_NO_UI_FRAMEWORK
        if deviceWrapper.orientation != .unknown {
            extraDeviceContext["orientation"]
            = deviceWrapper.orientation.isPortrait ? "portrait" : "landscape"
        }

        if deviceWrapper.isBatteryMonitoringEnabled {
            extraDeviceContext["charging"] = NSNumber(value: deviceWrapper.batteryState == .charging)
            extraDeviceContext["battery_level"] = NSNumber(value: Int(deviceWrapper.batteryLevel * 100))
        }

        #if !targetEnvironment(macCatalyst)
        // The hinge of foldable devices, such as iPhone Duo, is only known once UIKit reported it,
        // which requires iOS 27.1 and a device with a hinge. The value mirrors the status of the
        // hinge breadcrumbs: closed, partially_open, or fully_open.
        if let hingeState = hingeObserver.currentState, hingeState.status != .unknown {
            extraDeviceContext["hinge_status"] = hingeState.status.breadcrumbValue
        }
        #endif // !targetEnvironment(macCatalyst)
        #endif
        return extraDeviceContext
    }
    
    private func getExtraAppContext() -> [String: Any] {
        [ SentryDeviceContextAppMemoryKey: NSNumber(value: self.memoryMetricsProvider.appMemorySize) ]
    }
}
// swiftlint:enable missing_docs
