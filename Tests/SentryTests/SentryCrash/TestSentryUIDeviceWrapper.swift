import Sentry

class TestSentryUIDeviceWrapper: SentryUIDeviceWrapper {
#if os(iOS)
    var internalOrientation = UIDeviceOrientation.portrait
    var internalIsBatteryMonitoringEnabled = true
    var internalBatteryLevel: Float = 0.6
    var interalBatteryState = UIDevice.BatteryState.charging

    override func orientation() -> UIDeviceOrientation {
        return internalOrientation
    }

    override func isBatteryMonitoringEnabled() -> Bool {
        return internalIsBatteryMonitoringEnabled
    }

    override func batteryLevel() -> Float {
        return internalBatteryLevel
    }

    override func batteryState() -> UIDevice.BatteryState {
        return interalBatteryState
    }
#endif
}
