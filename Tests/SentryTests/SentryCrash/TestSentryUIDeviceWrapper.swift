@_spi(Private) import Sentry

#if os(iOS) || targetEnvironment(macCatalyst)
class TestSentryUIDeviceWrapper: SentryUIDeviceWrapper {
    
    var internalOrientation = UIDeviceOrientation.portrait
    var internalIsBatteryMonitoringEnabled = true
    var internalBatteryLevel: Float = 0.6
    var internalBatteryState = UIDevice.BatteryState.charging
    var started = false
    var internalCurrentDevice = UIDevice.current

    func start() {
        started = true
    }
    func stop() {
        started = false
    }

    var currentDevice: UIDevice {
        return internalCurrentDevice
    }

    var orientation: UIDeviceOrientation {
        return internalOrientation
    }

    var isBatteryMonitoringEnabled: Bool {
        return internalIsBatteryMonitoringEnabled
    }

    var batteryLevel: Float {
        return internalBatteryLevel
    }

    var batteryState: UIDevice.BatteryState {
        return internalBatteryState
    }
    
    func getSystemVersion() -> String {
        ""
    }
}
#endif // os(iOS) || targetEnvironment(macCatalyst)
