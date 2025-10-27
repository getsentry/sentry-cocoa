@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryExtraContextProvider: NSObject {
    
    private static let kSentryProcessInfoThermalStateNominal = "nominal"
    private static let kSentryProcessInfoThermalStateFair = "fair"
    private static let kSentryProcessInfoThermalStateSerious = "serious"
    private static let kSentryProcessInfoThermalStateCritical = "critical"
    
    private let crashWrapper: SentryCrashWrapper
    private let processInfoWrapper: SentryProcessInfoSource
    
    #if (os(iOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
    private let deviceWrapper: SentryUIDeviceWrapper

    init(crashWrapper: SentryCrashWrapper, processInfoWrapper: SentryProcessInfoSource, deviceWrapper: SentryUIDeviceWrapper) {
        self.crashWrapper = crashWrapper
        self.processInfoWrapper = processInfoWrapper
        self.deviceWrapper = deviceWrapper
    }
    #else
    init(crashWrapper: SentryCrashWrapper, processInfoWrapper: SentryProcessInfoSource) {
        self.crashWrapper = crashWrapper
        self.processInfoWrapper = processInfoWrapper
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
            SentryDeviceContextFreeMemoryKey: NSNumber(value: crashWrapper.freeMemorySize),
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
        
        #if (os(iOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
        if deviceWrapper.orientation != .unknown {
            extraDeviceContext["orientation"]
            = deviceWrapper.orientation.isPortrait ? "portrait" : "landscape"
        }

        if deviceWrapper.isBatteryMonitoringEnabled {
            extraDeviceContext["charging"] = NSNumber(value: deviceWrapper.batteryState == .charging)
            extraDeviceContext["battery_level"] = NSNumber(value: Int(deviceWrapper.batteryLevel * 100))
        }
        #endif
        return extraDeviceContext
    }
    
    private func getExtraAppContext() -> [String: Any] {
        [ SentryDeviceContextAppMemoryKey: NSNumber(value: self.crashWrapper.appMemorySize) ]
    }
}
